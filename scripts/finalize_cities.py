"""Join the GeoNames preferred Arabic names onto the city table and emit the
bundled asset."""
import json, re, unicodedata

ARAB_COUNTRIES = {
    "مصر", "السعودية", "الإمارات", "الكويت", "قطر", "البحرين", "عُمان", "اليمن",
    "الأردن", "فلسطين", "لبنان", "سوريا", "العراق", "ليبيا", "تونس", "الجزائر",
    "المغرب", "موريتانيا", "السودان", "الصومال", "جيبوتي", "جزر القمر",
}
COUNTRY_EN = {
    "مصر": "Egypt", "السعودية": "Saudi Arabia", "الإمارات": "UAE",
    "الكويت": "Kuwait", "قطر": "Qatar", "البحرين": "Bahrain", "عُمان": "Oman",
    "اليمن": "Yemen", "الأردن": "Jordan", "فلسطين": "Palestine",
    "لبنان": "Lebanon", "سوريا": "Syria", "العراق": "Iraq", "ليبيا": "Libya",
    "تونس": "Tunisia", "الجزائر": "Algeria", "المغرب": "Morocco",
    "موريتانيا": "Mauritania", "السودان": "Sudan", "الصومال": "Somalia",
    "جيبوتي": "Djibouti", "جزر القمر": "Comoros", "تركيا": "Turkey",
    "إيران": "Iran", "باكستان": "Pakistan", "إندونيسيا": "Indonesia",
    "ماليزيا": "Malaysia", "بنغلاديش": "Bangladesh", "أفغانستان": "Afghanistan",
    "نيجيريا": "Nigeria", "أذربيجان": "Azerbaijan", "كازاخستان": "Kazakhstan",
    "أوزبكستان": "Uzbekistan", "السنغال": "Senegal", "مالي": "Mali",
    "تشاد": "Chad", "النيجر": "Niger", "بريطانيا": "United Kingdom",
    "فرنسا": "France", "ألمانيا": "Germany", "الولايات المتحدة": "United States",
    "كندا": "Canada", "الهند": "India", "أستراليا": "Australia",
    "إسبانيا": "Spain", "إيطاليا": "Italy", "هولندا": "Netherlands",
    "بلجيكا": "Belgium", "السويد": "Sweden", "روسيا": "Russia",
    "الصين": "China", "جنوب أفريقيا": "South Africa", "البرازيل": "Brazil",
    "الأرجنتين": "Argentina", "تايلاند": "Thailand", "الفلبين": "Philippines",
    "اليابان": "Japan", "كوريا الجنوبية": "South Korea", "إثيوبيا": "Ethiopia",
    "كينيا": "Kenya", "تنزانيا": "Tanzania", "غانا": "Ghana",
    "ساحل العاج": "Ivory Coast", "الكاميرون": "Cameroon", "أوغندا": "Uganda",
    "ألبانيا": "Albania", "البوسنة": "Bosnia", "كوسوفو": "Kosovo",
    "مقدونيا": "North Macedonia", "سويسرا": "Switzerland", "النمسا": "Austria",
    "اليونان": "Greece", "البرتغال": "Portugal", "النرويج": "Norway",
    "الدنمارك": "Denmark", "فنلندا": "Finland", "أيرلندا": "Ireland",
    "نيوزيلندا": "New Zealand", "المكسيك": "Mexico",
    "تركمانستان": "Turkmenistan", "طاجيكستان": "Tajikistan",
    "قيرغيزستان": "Kyrgyzstan", "سريلانكا": "Sri Lanka", "المالديف": "Maldives",
    "بروناي": "Brunei", "ميانمار": "Myanmar", "نيبال": "Nepal",
}
PREFIXES = ["محافظة ", "ولاية ", "منطقة ", "إقليم ", "مركز ", "مدينة ", "عمالة ",
            "إمارة ", "مقاطعة ", "جهة ", "لواء ", "قضاء ", "بلدية "]
ARABIC_RANGE = re.compile(r"[؀-ۿ]")


def clean(text):
    """Strip the bidi marks and stray control characters GeoNames carries."""
    return "".join(
        ch for ch in text
        if unicodedata.category(ch) != "Cf"
    ).strip()


def fold(text):
    """Alef and hamza spellings vary; "الاسكندرية" and "الإسكندرية" are one word."""
    for source, target in (("أإآٱ", "ا"), ("ة", "ه"), ("ى", "ي")):
        for char in source:
            text = text.replace(char, target)
    text = "".join(ch for ch in text if not ("\u064b" <= ch <= "\u0652"))
    return text.replace("ـ", "").strip()


def tidy(admin, city):
    for prefix in PREFIXES:
        if admin.startswith(prefix):
            admin = admin[len(prefix):]
    admin = admin.strip()
    return "" if fold(admin) == fold(city) else admin


ARTICLE_EN = ("Al ", "Al-", "El ", "El-", "Ad ", "Az ", "As ", "Ar ", "An ",
              "At ", "Ath ", "Ash ", "Ad-", "As-", "Ar-", "An-")


def restore_article(name_ar, name_en):
    """GeoNames sometimes drops the definite article from the Arabic entry —
    "منصورة" for a city everyone calls "المنصورة". The Latin name keeps it."""
    if name_ar.startswith("ال") or not name_en.startswith(ARTICLE_EN):
        return name_ar
    return "ال" + name_ar


def strip_admin_en(admin):
    admin = re.sub(r"^(Muḩāfaz̧at|Muhafazat|Governorate of|Wilayat|Mintaqat)\s+", "", admin)
    return re.sub(r"\s+(Governorate|Province|Region|District)$", "", admin).strip()


cities = json.load(open("cities_raw.json", encoding="utf-8"))
names = json.load(open("ar_names.json", encoding="utf-8"))

out = []
dropped = 0
for row in cities:
    name_ar = restore_article(clean(names.get(str(row["id"]), row["ar"])), row["en"])
    admin_id = row.pop("adminId", 0)
    admin_ar = clean(names.get(str(admin_id), row.get("adminAr", "")))
    admin_ar = tidy(admin_ar, name_ar)
    country_ar = row["countryAr"]

    # An Arabic screen has no use for a Latin-only name in an Arab country.
    if country_ar in ARAB_COUNTRIES and not ARABIC_RANGE.search(name_ar):
        dropped += 1
        continue

    out.append({
        "ar": name_ar,
        "en": row["en"],
        "aAr": admin_ar,
        "aEn": strip_admin_en(clean(row.get("adminEn", ""))),
        "cAr": country_ar,
        "cEn": COUNTRY_EN.get(country_ar, country_ar),
        "lat": row["lat"],
        "lon": row["lon"],
        "t": row["t"],
    })

json.dump(out, open("cities.json", "w", encoding="utf-8"),
          ensure_ascii=False, separators=(",", ":"))
print("kept %d, dropped %d Latin-only Arab entries" % (len(out), dropped))
