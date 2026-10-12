"""Whisper-friendly Turkmen sentence seed.

The file is loaded into the ``sentences`` table on startup (idempotent).
Add new packages by appending to ``packages`` and ``sentences`` — the API
picks them up on the next restart, the mobile app downloads them offline.
"""

from __future__ import annotations

import json
from pathlib import Path

PACKAGES = [
    {
        "id": "package_001",
        "name": "Gündelik gepleşik",
        "description": "Gündelik durmuşda iň köp ulanylýan gysga sözlemler.",
        "category": "daily",
        "language": "tk",
    },
    {
        "id": "package_002",
        "name": "Sanlar we wagt",
        "description": "Sanlar, sagat, seneler we mukdarlar bilen sözlemler.",
        "category": "numbers",
        "language": "tk",
    },
    {
        "id": "package_003",
        "name": "Tebigat we howa",
        "description": "Howa, pasyllar, tebigat we daşky gurşaw.",
        "category": "nature",
        "language": "tk",
    },
    {
        "id": "package_004",
        "name": "Bilim, iş we tehnologiýa",
        "description": "Mekdep, iş ýerli we tehnologiýa bilen bagly sözlemler.",
        "category": "education",
        "language": "tk",
    },
    {
        "id": "package_005",
        "name": "Soraglar we jogaplar",
        "description": "Gepleşikde ulanylýan sorag we jogap sözlemleri.",
        "category": "questions",
        "language": "tk",
    },
    {
        "id": "package_006",
        "name": "Ýerler we medeniýet",
        "description": "Türkmenistanyň ýerleri, taryhy we medeni mirasy.",
        "category": "culture",
        "language": "tk",
    },
]

DAILY = [
    "Men şu gün täze kitap okadym.",
    "Ertir irden işe gitmeli bolaryn.",
    "Maşgalam bilen agşam nahar iýýäris.",
    "Ejeme bazarda gül satyn alaryn.",
    "Günüň dowamynda köp suw içmeli.",
    "Çagalar howluda top oýnaýarlar.",
    "Men her gün irden turýaryn.",
    "Şu gün howa örän yssy boldy.",
    "Aşpez tagam bişirmäge başlady.",
    "Men size kömek etmäge taýýar.",
    "Kitaphanada oturup işledim.",
    "Geljek hepde oba gitjek.",
    "Meniň iş günüm sagat sekizde başlaýar.",
    "Dostum bilen telefon arkaly gürleşdim.",
    "Öýümi arassalap, soň dynç aldym.",
    "Şu gün ýekşenbe, dükanlar ýapyk.",
    "Kakam myhmanlary garşylady.",
    "Men täze aýakgap satyn aldym.",
    "Gapyny ýapyp, jaňy goýber.",
    "Çaý içip, bir az gepleşeliň.",
    "Bize agşam myhman gelmegi mümkin.",
    "Ol jaň edip, nahar sargyt etdi.",
    "Meniň doganym mekdepde okaýar.",
    "Agşamlyk nahar taýýar boldy.",
    "Men iki sany alma we bir armyt aldym.",
    "Ýolda goňşym bilen salamlaşdym.",
    "Öý işleri köp, ýöne wagtym az.",
    "Çagalar irden mekdebe gidýärler.",
    "Ussa diwary reňkläp taýýarlady.",
    "Men ertirlik üçin ýumurtga we çörek iýdim.",
    "Kir ýuwup, soň çaý demledim.",
    "Men ertir şähere gitmegi meýilleşdirýärin.",
    "Ejem miwe jöwzasyndan kompot bişirdi.",
    "Biz howluda agaç oturdysdyk.",
    "Gijeki gepleşik uzaga çekdi.",
    "Men täze futbol kubogyny satyn aldym.",
    "Çagalar süýtli çaý içmegi halaýarlar.",
    "Seniň aýdanyň dogry, men razylaşýaryn.",
    "Men birnäçe ýyllap bu ýerde işleýärin.",
    "Şu gün öýüme ir dolandym.",
]

NUMBERS = [
    "Häzir sagat on iki boldy.",
    "Bu kitabyň bahasy otuz manat.",
    "Men on bäş minut garaşdym.",
    "Ýyl iki müň ýigrimi altynjy ýyl.",
    "Tomusda üç aý dynç alýarys.",
    "Sanawy ikinji gezek barladym.",
    "Biziň obamyzda ýüz otuz maşgala ýaşaýar.",
    "Kitabymyň basylan ýyly bäş ýyl öň.",
    "Biz üçünji gatda ýaşaýarys.",
    "Ýedi günüň dowamynda işledim.",
    "Wagtyňy dogry paýlaşmak örän möhüm.",
    "Sagat ýedide agşamlyk nahar iýýäris.",
    "Sanlar matematikanyň esasy bölegi.",
    "Onuň doglan güni ýigriminji maýda.",
    "Birinji synpda otuz okuwçy bar.",
    "Bäş ýyldan soň ýene duşuşarys.",
    "Üç sagatdan soň size jaň ederin.",
    "Biziň toparymyzda ýigrimi adam bar.",
    "Şu ýylyň dowamynda ýüz müň sözlem ýygnamaly.",
    "Ikinji synanyşykda netije gowulaşdy.",
    "Müň metr ýol pyýada gitdik.",
    "Onuň agramy elli iki kilogram boldy.",
    "Ýarym sagatdan soň başlarys.",
    "Men bu filmi dört gezek gördüm.",
    "Ýygyrmy dört sagat dowam eden ýol.",
    "Ýüz ýigrimi kilometr ýol geçdik.",
    "Çärýek sagat garaşmagyňyzy haýyş edýärin.",
    "Bäş minutdan täzelemäni barlap gör.",
    "Alty sany stol we sekiz oturgyç gerek.",
    "Dokuzynjy synagda maksat hasyl boldy.",
    "Ýigrimi bäş göterim arzanladyş bar.",
    "Üçünji tapgyr ertir başlaýar.",
    "On minutlyk arakesme yglan edildi.",
    "Meniň telefon belgim iki bilen başlaýar.",
    "Şu ýazgynyň dowamlylygy on sekiz sekunt.",
]

NATURE = [
    "Howanyň ýagdaýy örän gowy.",
    "Ýagyş ýagýar, şemsiýäňi özüň bilen al.",
    "Gyşda daglarda gar köp bolýar.",
    "Ýaz gelende baglar gülläp başlaýar.",
    "Gün ýaşyp, asmana ýyldyzlar çykdy.",
    "Şemal güýçli öwüsýär.",
    "Günorta gün örän gyzdyryp dur.",
    "Hazar deňziniň suwy turgenç.",
    "Daglaryň howasy arassa we salkyn.",
    "Güýzde ýapraklar sary reňke öwrülýär.",
    "Ýyldyrym çakyp, ýagyş başlady.",
    "Bahar paslynda güller açýar.",
    "Aprel aýynda ýagyşly günler köp bolýar.",
    "Çölde gündiz yssy, gije sowuk bolýar.",
    "Gar eräp, derýalar joşýar.",
    "Bagyň miweleri bu ýyl bol hasyl berdi.",
    "Derýanyň suwy arassa we sowuk.",
    "Guşlar gyşlamak üçin ýyly ýurtlara uçýar.",
    "Tokaýda dürli haýwanlar ýaşaýar.",
    "Gün doganda oba ýagtylyga çümýär.",
    "Aý asmanda doly görünýär.",
    "Ýazky ýagyşlar ekinlere peýdaly.",
    "Sähra ösümlikleri suwa çydamly.",
    "Deňiz şemaly ýüzüme öwüsdi.",
    "Tomusda gün uzyn, gije gysga bolýar.",
    "Bu ýyl gyş örän sowuk geldi.",
    "Bulutlar ýygnanyp, howa üýtgedi.",
    "Ýeriň ysy ýagyşdan soň ýaýraýar.",
    "Daglaryň üstünde bulutlar süýşýär.",
    "Ekin meýdanlary ýaşyl reňke beslendi.",
    "Güneşli günde dynç almak ýakymly.",
    "Tepegöz guşy asmanda aýlanyp uçýar.",
    "Bahar ýagşyndan soň howa arassalanýar.",
    "Suw çeşmeleri oba üçin gymmatly.",
    "Tebigaty goramak her birimiziň borjumyz.",
]

EDUCATION = [
    "Mekdepde okuwçylar iňlis dilini öwrenýärler.",
    "Mugallym bize täze sapak berdi.",
    "Uniwersitetde iki fakultet bar.",
    "Men programmirlemek boýunça okaýaryn.",
    "Iş tapgyrynda möhüm duşuşyk geçirildi.",
    "Täze taslama boýunça teklip taýýarladym.",
    "Mugallym okuwçylara baha goýdy.",
    "Işde düzgün-tertibe boýun bolmaly.",
    "Biz bu meseläni bilelikde çözdük.",
    "Okuw ýyly sentýabrda başlaýar.",
    "Alymlar gadymy golýazmalary tapdylar.",
    "Inžener täze köpriniň dizaýnyny taýýarlady.",
    "Lukmanlar hassananyň işini gowulandyrýarlar.",
    "Barlagyň netijesi bugün yglan edildi.",
    "Kompýuter çalt we ygtybarly işleýär.",
    "Telefonymyň batareýasy gutardy.",
    "Internet baglanyşygy örän wagtlaýyn.",
    "Programma üstünlikli gurnaldy.",
    "Maglumatlaryň ätiýaçlyk nusgasyny saklaň.",
    "Bu saýtda gözleg ulanyp, maglumat tapyp bolýar.",
    "Emeli aň täze mümkinçilikleri açýar.",
    "Ses ýazgy etmek üçin mikrofony ulanýarys.",
    "Faýl awtomatiki ýagdaýda serwere iberilýär.",
    "Programmanyň täze görnüşi çykdy.",
    "Elektrik togy bäş minut ýok boldy.",
    "Ulanyjy täze hasabyny döretdi.",
    "Paroly hiç kime aýtmazlyk gerek.",
    "Programma maglumatlary ýerli saklaýar.",
    "Internet pes bolsa, ýazgy nobatda saklanar.",
    "Biz faýllary bulutly ammarda saklaýarys.",
    "Mugallym sorag berip, jogabyny barlady.",
    "Okuwçylar tejribe işini tamamladylar.",
    "Kitabhanada täze kitaplar goýuldy.",
    "Dil öwrenmek üçin her gün türgenleşmeli.",
    "Ýygnan maglumatlar model öwretmek üçin ulanylýar.",
]

QUESTIONS = [
    "Sen nirede ýaşaýarsyň?",
    "Bu gün howa nähili bolýar?",
    "Bize haçan geljek?",
    "Näme üçin jaň etmediň?",
    "Siz türkmençe gepleýärsiňizmi?",
    "Meniň bilen gitmek isleýärsiňmi?",
    "Awtobus haçan ýola düşýär?",
    "Näçe sagat wagt gerek?",
    "Siz bu kitaby okadyňyzmy?",
    "Bilermenlere ýüz tutmalymy?",
    "Çaýyňyza süýt goşýarysmy?",
    "Haýsy ýol has gysga bolýar?",
    "Seniň işiň nähili geçýär?",
    "Şu gün bize näme etmeli?",
    "Bu sözlemi dogry okap bilýärsiňizmi?",
    "Näçe sany ýazgy taýýarladyňyz?",
    "Siz nähili dilleri bilýärsiňiz?",
    "Meniň sesim aýdyň eşidilýärmi?",
    "Taýýarmy, başlalyňmy?",
    "Galaýy bu ýerde arzanmy?",
    "Men nädip kömek edip bilerin?",
    "Şu wagt elýeterlimi?",
    "Duşuşygy ertire geçirsek bolarmy?",
    "Bu ýazgyny täzeden diňläp göreliňmi?",
    "Seniň pikiriňçe haýsysy has gowy?",
    "Biletleri onlaýn almalymy?",
    "Öýde kim bar?",
    "Şu telefony nireden aldyn?",
    "Bize náhili maslahat berersiňiz?",
    "Lukmana haçan ýazylmaly?",
    "Meni diňleýärsiňizmi?",
    "Bu ýerde dükan barmy?",
    "Hany, ýene bir gezek gaýtala?",
    "Wagtyň bar bolsa, biraz gepleşeliň.",
    "Siz nähili pikir edýärsiňiz?",
]

CULTURE = [
    "Aşgabat şäheriň köçeleri giň we arassa.",
    "Mary welaýaty gadymy taryhy bilen tanalýar.",
    "Türkmenabat şäheri Amyderýanyň boýunda ýerleşýär.",
    "Daşoguz welaýaty demirgazykda ýerleşýär.",
    "Balkanabat şäherinde köp senagat kärhanasy bar.",
    "Hazar deňzi Türkmenistanyň günbatar serhedinde.",
    "Köpetdagyň eteklerinde obalar köp.",
    "Merviň harabalyklary dünýä mirasyna girýär.",
    "Türkmen elipbiýinde otuz harf bar.",
    "Türkmen dili biziň medeni mirasymyzdyr.",
    "Türkmen halysy dünýäde meşhurdyr.",
    "Ahalteke atlary çalt çapýarlar.",
    "Nowruz baýramy bahar paslynda bellenilýär.",
    "Bagşy dutar çalyp, aýdym aýdýar.",
    "Çagalar dutar öwrenmegi halaýarlar.",
    "Gadymy golýazmalar muzeýde saklanýar.",
    "Türkmen milli lybasy nepis nagyşlar bilen bezelýär.",
    "Milli tagamlar myhmanlara hödürlenýär.",
    "Garagum çöli özüniň gözelligi bilen tanalýar.",
    "Atçylyk sporty ýurdumyzda ösen.",
    "Küşt oýny çylşyrymly pikirlenmegi öwredýär.",
    "Milli aýdym-saz mirasymyz nesilden-nesle geçýär.",
    "Türkmenistanda dört pasyl aýdyň duýulýar.",
    "Awtoulag ýollary ýurdumyzyň şäherlerini baglanyşdyrýar.",
    "Ýurdumyzyň tebigy baýlyklary köpdür.",
    "Täze binalar şäherleriň keşbini üýtgedýär.",
    "Döwlet taryhy ýadygärlikleri goraýar.",
    "Köne şäherleriň harabalary arheologlar üçin gymmatly.",
    "Nusay ýazgylary gadymy döwürden habar berýär.",
    "Jemgyýetde hormat we mähir möhümdir.",
    "Umuman, dilimiz edebiýatymyzyň gözbasydyr.",
    "Her halk öz taryhyny bilmeli.",
    "Ýaşlar milli däp-dessurlary öwrenýärler.",
    "Sungat adam ruhuny baýlaşdyrýar.",
    "Berkarar döwlet gurmak umumy maksatdyr.",
]


def _build() -> dict:
    groups = [
        ("package_001", DAILY),
        ("package_002", NUMBERS),
        ("package_003", NATURE),
        ("package_004", EDUCATION),
        ("package_005", QUESTIONS),
        ("package_006", CULTURE),
    ]
    package_categories = {package["id"]: package["category"] for package in PACKAGES}
    sentences: list[dict] = []
    counter = 0
    for package_id, texts in groups:
        for index, text in enumerate(texts):
            counter += 1
            word_count = len(text.split())
            sentences.append(
                {
                    "id": f"sentence_{counter:06d}",
                    "text": text,
                    "language": "tk",
                    "category": package_categories[package_id],
                    "package_id": package_id,
                    "difficulty": 1 if word_count <= 6 else 2 if word_count <= 10 else 3,
                    "order": index,
                }
            )
    return {
        "language": "tk",
        "version": 1,
        "created_at": "2026-01-01T00:00:00+00:00",
        "packages": PACKAGES,
        "sentences": sentences,
    }


def main() -> None:
    payload = _build()
    target = Path(__file__).parent.parent / "app" / "data" / "sentences_seed.json"
    target.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"wrote {len(payload['sentences'])} sentences to {target}")


if __name__ == "__main__":
    main()
