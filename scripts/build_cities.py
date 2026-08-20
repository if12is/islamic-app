"""Build the offline nearest-city table from GeoNames.

GeoNames ships an alternate-names column that carries the Arabic spelling for
almost every populated place, and ADM1 rows in the same file carry the Arabic
name of the governorate. That makes one download per country enough to say
"دمنهور، البحيرة، مصر" with no network at run time.
"""
import io, json, os, re, sys, urllib.request, zipfile

BASE = "https://download.geonames.org/export/dump/"
HERE = os.path.dirname(os.path.abspath(__file__))
ARABIC_RE = re.compile(r"^[؀-ۿ\sـ'’\-]+$")
# Letters that only appear in Persian, Urdu, Pashto or Kurdish spellings. GeoNames
# lists those beside the Arabic ones, and picking one would label an Egyptian
# governorate in Persian.
NON_ARABIC_LETTERS = set("پچژگکیےۆەێڵڕڤۀہھڈڑںٹۇۈۋۅ")

ARAB = {
    "EG": "مصر", "SA": "السعودية", "AE": "الإمارات", "KW": "الكويت", "QA": "قطر",
    "BH": "البحرين", "OM": "عُمان", "YE": "اليمن", "JO": "الأردن", "PS": "فلسطين",
    "LB": "لبنان", "SY": "سوريا", "IQ": "العراق", "LY": "ليبيا", "TN": "تونس",
    "DZ": "الجزائر", "MA": "المغرب", "MR": "موريتانيا", "SD": "السودان",
    "SO": "الصومال", "DJ": "جيبوتي", "KM": "جزر القمر",
}
WORLD = {
    "TR": "تركيا", "IR": "إيران", "PK": "باكستان", "ID": "إندونيسيا", "MY": "ماليزيا",
    "BD": "بنغلاديش", "AF": "أفغانستان", "NG": "نيجيريا", "AZ": "أذربيجان",
    "KZ": "كازاخستان", "UZ": "أوزبكستان", "SN": "السنغال", "ML": "مالي",
    "TD": "تشاد", "NE": "النيجر", "GB": "بريطانيا", "FR": "فرنسا", "DE": "ألمانيا",
    "US": "الولايات المتحدة", "CA": "كندا", "IN": "الهند", "AU": "أستراليا",
    "ES": "إسبانيا", "IT": "إيطاليا", "NL": "هولندا", "BE": "بلجيكا",
    "SE": "السويد", "RU": "روسيا", "CN": "الصين", "ZA": "جنوب أفريقيا",
    "BR": "البرازيل", "AR": "الأرجنتين", "TH": "تايلاند", "PH": "الفلبين",
    "JP": "اليابان", "KR": "كوريا الجنوبية", "ET": "إثيوبيا", "KE": "كينيا",
    "TZ": "تنزانيا", "GH": "غانا", "CI": "ساحل العاج", "CM": "الكاميرون",
    "UG": "أوغندا", "AL": "ألبانيا", "BA": "البوسنة", "XK": "كوسوفو",
    "MK": "مقدونيا", "CH": "سويسرا", "AT": "النمسا", "GR": "اليونان",
    "PT": "البرتغال", "NO": "النرويج", "DK": "الدنمارك", "FI": "فنلندا",
    "IE": "أيرلندا", "NZ": "نيوزيلندا", "MX": "المكسيك", "TM": "تركمانستان",
    "TJ": "طاجيكستان", "KG": "قيرغيزستان", "LK": "سريلانكا", "MV": "المالديف",
    "BN": "بروناي", "MM": "ميانمار", "NP": "نيبال",
}
PREFIXES = ["محافظة ", "ولاية ", "منطقة ", "إقليم ", "مركز ", "مدينة ", "عمالة ",
            "إمارة ", "مقاطعة ", "جهة ", "لواء ", "قضاء ", "بلدية "]


def fetch(name):
    path = os.path.join(HERE, name)
    if not os.path.exists(path):
        print("  downloading %s" % name, file=sys.stderr, flush=True)
        urllib.request.urlretrieve(BASE + name, path)
    return path


def rows_of(zip_path, member):
    with zipfile.ZipFile(zip_path) as archive:
        with archive.open(member) as handle:
            for line in io.TextIOWrapper(handle, encoding="utf-8"):
                if line.strip():
                    yield line.rstrip("\n").split("\t")


def arabic_candidates(alternates):
    found = []
    for candidate in alternates.split(","):
        candidate = candidate.strip()
        if len(candidate) < 3 or not ARABIC_RE.match(candidate):
            continue
        if set(candidate) & NON_ARABIC_LETTERS:
            continue
        found.append(candidate)
    return found


def arabic_name(alternates, fallback):
    """Shortest spelling wins: GeoNames lists transliterations beside the real
    name, and the real one is almost always the tersest ("لندن", not "لأندأن").
    The one exception is the definite article — "المنصورة" is the name, and
    "منصورة" is the same name with a piece missing."""
    found = arabic_candidates(alternates)
    if not found:
        return fallback
    shortest = min(found, key=len)
    with_article = "ال" + shortest
    return with_article if with_article in found else shortest


def admin_name(alternates, fallback):
    found = arabic_candidates(alternates)
    if not found:
        return fallback
    formal = [
        name for name in found
        if name.startswith(("محافظة", "منطقة", "ولاية", "إمارة", "جهة", "مقاطعة"))
    ]
    return min(formal or found, key=len)


def tidy(admin, city):
    for prefix in PREFIXES:
        if admin.startswith(prefix):
            admin = admin[len(prefix):]
    admin = admin.strip()
    return "" if admin == city else admin


cities = []

for code, country_ar in ARAB.items():
    print("%s ..." % country_ar, file=sys.stderr, flush=True)
    path = fetch(code + ".zip")
    admins = {}
    places = []
    for row in rows_of(path, code + ".txt"):
        if len(row) < 15:
            continue
        if row[7] == "ADM1":
            admins[row[10]] = (admin_name(row[3], row[1]), int(row[0]), row[2])
        elif row[6] == "P" and row[14].isdigit() and int(row[14]) >= 15000:
            places.append(row)

    aliases = {}
    for row in rows_of(path, code + ".txt"):
        if len(row) < 15:
            continue
        found = arabic_candidates(row[3])
        if not found:
            continue
        best = min(found, key=len)
        for alias in [row[1], row[2]] + row[3].split(","):
            alias = alias.strip().lower()
            if alias:
                aliases.setdefault(alias, []).append(
                    (best, float(row[4]), float(row[5]))
                )

    for row in places:
        name_ar = arabic_name(row[3], row[1])
        if not arabic_candidates(row[3]):
            lat, lon = float(row[4]), float(row[5])
            for alias in [row[1], row[2]] + row[3].split(","):
                matches = aliases.get(alias.strip().lower())
                if not matches:
                    continue
                near = [
                    name for name, alat, alon in matches
                    if abs(alat - lat) < 0.5 and abs(alon - lon) < 0.5
                ]
                if near:
                    name_ar = min(near, key=len)
                    break
        admin_pair = admins.get(row[10], ("", 0, ""))
        admin_ar = tidy(admin_pair[0], name_ar)
        cities.append({
            "id": int(row[0]),
            "ar": name_ar,
            "en": row[2],
            "adminAr": admin_ar,
            "adminId": admin_pair[1],
            "adminEn": admin_pair[2],
            "countryAr": country_ar,
            "lat": round(float(row[4]), 4),
            "lon": round(float(row[5]), 4),
            "pop": int(row[14]),
        })

print("world file ...", file=sys.stderr, flush=True)
path = fetch("cities15000.zip")
for row in rows_of(path, "cities15000.txt"):
    if len(row) < 15 or row[8] not in WORLD:
        continue
    if not row[14].isdigit() or int(row[14]) < 250000:
        continue
    cities.append({
        "id": int(row[0]),
        "ar": arabic_name(row[3], row[1]),
        "en": row[2],
        "adminAr": "",
        "countryAr": WORLD[row[8]],
        "lat": round(float(row[4]), 4),
        "lon": round(float(row[5]), 4),
        "pop": int(row[14]),
    })

cities.sort(key=lambda row: -row["pop"])
seen = set()
unique = []
for row in cities:
    key = (row["ar"], row["countryAr"], round(row["lat"], 1), round(row["lon"], 1))
    if key in seen:
        continue
    seen.add(key)
    # A coarse size tier is enough to stop a 20k-person suburb from outranking
    # the city it sits inside when both are a few kilometres away.
    population = row.pop("pop")
    row["t"] = (
        4 if population >= 2000000 else
        3 if population >= 500000 else
        2 if population >= 150000 else
        1 if population >= 50000 else 0
    )
    unique.append(row)

with open(os.path.join(HERE, "cities_raw.json"), "w", encoding="utf-8") as handle:
    json.dump(unique, handle, ensure_ascii=False, separators=(",", ":"))
print("DONE %d cities" % len(unique), file=sys.stderr, flush=True)
