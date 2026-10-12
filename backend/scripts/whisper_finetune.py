"""Fine-tune Whisper on the Türkmen Ses dataset (optional heavy deps).

    pip install "transformers>=4.44" "datasets>=2.20" "evaluate>=0.4" jiwer torch accelerate librosa soundfile
    python scripts/whisper_finetune.py --dataset whisper_dataset --model openai/whisper-small --output whisper-tk

The script is intentionally small: it loads the jsonl splits produced by
``build_whisper_dataset.py``, prepares Whisper features, trains with
``Seq2SeqTrainer`` and reports WER/CER.  Run it on a GPU (Colab/Kaggle is
enough for whisper-small).
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path


def load_rows(dataset_dir: Path, split: str) -> list[dict]:
    path = dataset_dir / f"{split}.jsonl"
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", default="whisper_dataset")
    parser.add_argument("--model", default="openai/whisper-small")
    parser.add_argument("--output", default="whisper-turkmen")
    parser.add_argument("--language", default="turkmen")
    parser.add_argument("--task", default="transcribe")
    parser.add_argument("--epochs", type=float, default=8)
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--gradient-accumulation", type=int, default=2)
    parser.add_argument("--learning-rate", type=float, default=1e-5)
    parser.add_argument("--warmup-steps", type=int, default=120)
    parser.add_argument("--eval-steps", type=int, default=120)
    parser.add_argument("--save-steps", type=int, default=240)
    parser.add_argument("--push-to-hub", default="")
    args = parser.parse_args()

    dataset_dir = Path(args.dataset)
    if not (dataset_dir / "train.jsonl").exists():
        raise SystemExit("train.jsonl tapylmady — öň build_whisper_dataset.py işlediň")

    try:
        import datasets
        import evaluate
        import torch
        from transformers import (
            Seq2SeqTrainer,
            Seq2SeqTrainingArguments,
            WhisperForConditionalGeneration,
            WhisperProcessor,
        )
    except ImportError as error:  # pragma: no cover
        raise SystemExit(
            "Gerekli paketler ýok: pip install transformers datasets evaluate jiwer torch librosa soundfile"
        ) from error

    processor = WhisperProcessor.from_pretrained(args.model, language=args.language, task=args.task)
    model = WhisperForConditionalGeneration.from_pretrained(args.model)
    model.generation_config.language = args.language
    model.generation_config.task = args.task
    model.generation_config.forced_decoder_ids = None
    model.config.use_cache = False

    feature_extractor = processor.feature_extractor

    def prepare(batch):
        audio = batch["audio"]
        batch["input_features"] = feature_extractor(
            audio["array"], sampling_rate=audio["sampling_rate"]
        ).input_features[0]
        batch["labels"] = processor.tokenizer(batch["text"]).input_ids
        return batch

    data_files = {
        "train": str(dataset_dir / "train.jsonl"),
        "validation": str(dataset_dir / "validation.jsonl"),
    }
    raw = datasets.load_dataset("json", data_files=data_files, cache_dir=".cache")
    audio_column = datasets.Audio(sampling_rate=16_000)
    raw = raw.cast_column("audio", audio_column)

    encoded = raw.map(prepare, remove_columns=raw["train"].column_names, num_proc=1)

    @dataclass
    class Collator:
        processor: object

        def __call__(self, features):
            input_features = [{"input_features": item["input_features"]} for item in features]
            batch = self.processor.feature_extractor.pad(input_features, return_tensors="pt")
            label_features = [{"input_ids": item["labels"]} for item in features]
            labels_batch = self.processor.tokenizer.pad(label_features, return_tensors="pt")
            labels = labels_batch["input_ids"].masked_fill(labels_batch.attention_mask.ne(1), -100)
            if (labels[:, 0] == self.processor.tokenizer.bos_token_id).all().cpu().item():
                labels = labels[:, 1:]
            batch["labels"] = labels
            return batch

    wer = evaluate.load("wer")
    cer = evaluate.load("cer")

    def compute_metrics(prediction):
        pred_ids = prediction.predictions
        label_ids = prediction.label_ids
        label_ids[label_ids == -100] = processor.tokenizer.pad_token_id
        pred_str = processor.batch_decode(pred_ids, skip_special_tokens=True)
        label_str = processor.batch_decode(label_ids, skip_special_tokens=True)
        return {
            "wer": 100 * wer.compute(predictions=pred_str, references=label_str),
            "cer": 100 * cer.compute(predictions=pred_str, references=label_str),
        }

    training_args = Seq2SeqTrainingArguments(
        output_dir=args.output,
        per_device_train_batch_size=args.batch_size,
        gradient_accumulation_steps=args.gradient_accumulation,
        learning_rate=args.learning_rate,
        warmup_steps=args.warmup_steps,
        num_train_epochs=args.epochs,
        gradient_checkpointing=True,
        fp16=torch.cuda.is_available(),
        evaluation_strategy="steps",
        per_device_eval_batch_size=args.batch_size,
        predict_with_generate=True,
        generation_max_length=225,
        save_steps=args.save_steps,
        eval_steps=args.eval_steps,
        logging_steps=25,
        report_to=["tensorboard"],
        load_best_model_at_end=True,
        metric_for_best_model="wer",
        greater_is_better=False,
        push_to_hub=bool(args.push_to_hub),
        hub_model_id=args.push_to_hub or None,
    )

    trainer = Seq2SeqTrainer(
        args=training_args,
        model=model,
        train_dataset=encoded["train"],
        eval_dataset=encoded.get("validation"),
        data_collator=Collator(processor),
        compute_metrics=compute_metrics,
        tokenizer=processor.feature_extractor,
    )
    trainer.train()
    trainer.save_model(args.output)
    processor.save_pretrained(args.output)
    if args.push_to_hub:
        trainer.push_to_hub()
    print(f"model saved to {args.output}")


if __name__ == "__main__":
    main()
