import Foundation

// MARK: - Reciter Model

/// Represents a Quran reciter with their identifier and display name
public struct Reciter: Identifiable, Codable, Hashable {
    public let id: String  // API identifier (e.g., "ar.alafasy")
    public let name: String  // Display name (e.g., "Mishary Rashid Alafasy")
    public let arabicName: String?  // Optional Arabic name

    public init(id: String, name: String, arabicName: String? = nil) {
        self.id = id
        self.name = name
        self.arabicName = arabicName
    }
}

// MARK: - Available Reciters

/// List of all available reciters from AlQuran.cloud API
public struct Reciters {
    public static let all: [Reciter] = [
        // Popular Arabic Reciters
        Reciter(id: "ar.alafasy", name: "Mishary Rashid Alafasy", arabicName: "مشاري بن راشد العفاسي"),
        Reciter(id: "ar.husary", name: "Mahmoud Khalil Al-Husary", arabicName: "محمود خليل الحصري"),
        Reciter(id: "ar.minshawi", name: "Mohamed Siddiq Al-Minshawi", arabicName: "محمد صديق المنشاوي"),
        Reciter(id: "ar.abdulbasitmurattal", name: "Abdul Basit (Murattal)", arabicName: "عبد الباسط عبد الصمد - مرتل"),
        Reciter(id: "ar.abdulbasitmujawwad", name: "Abdul Basit (Mujawwad)", arabicName: "عبد الباسط عبد الصمد - مجود"),
        Reciter(id: "ar.shaatree", name: "Abu Bakr Al-Shatri", arabicName: "أبو بكر الشاطري"),
        Reciter(id: "ar.ahmedajamy", name: "Ahmed ibn Ali al-Ajamy", arabicName: "أحمد بن علي العجمي"),
        Reciter(id: "ar.hanirifai", name: "Hani ar-Rifai", arabicName: "هاني الرفاعي"),
        Reciter(id: "ar.hudhaify", name: "Ali ibn Abdur-Rahman al-Hudhaify", arabicName: "علي بن عبدالرحمن الحذيفي"),
        Reciter(id: "ar.muaiqly", name: "Maher Al Muaiqly", arabicName: "ماهر المعيقلي"),
        Reciter(id: "ar.muhammadayyoub", name: "Muhammad Ayyub", arabicName: "محمد أيوب"),
        Reciter(id: "ar.muhammadjibreel", name: "Muhammad Jibreel", arabicName: "محمد جبريل"),
        Reciter(id: "ar.parhizgar", name: "Abdulbasit Abdulsamad (Parhizgar)", arabicName: "عبدالباسط عبدالصمد"),
        Reciter(id: "ar.saoodshuraym", name: "Saood bin Ibraaheem Ash-Shuraym", arabicName: "سعود الشريم"),
        Reciter(id: "ar.abdullahbasfar", name: "Abdullah Basfar", arabicName: "عبدالله بصفر"),
        Reciter(id: "ar.abdurrahmaansudais", name: "Abdur-Rahman As-Sudais", arabicName: "عبد الرحمن السديس"),
        Reciter(id: "ar.banderalbalushi", name: "Bandar Baleela", arabicName: "بندر بليلة"),
        Reciter(id: "ar.khalilalhusary", name: "Khalil Al-Husary", arabicName: "خليل الحصري"),
        Reciter(id: "ar.mahmoudalkhalil", name: "Mahmoud Al-Khalil Al-Qari", arabicName: "محمود القارئ"),
        Reciter(id: "ar.mahermuaiqly", name: "Maher Al-Muaiqly (Alternative)", arabicName: "ماهر المعيقلي"),
        Reciter(id: "ar.mostafaismail", name: "Mostafa Ismail", arabicName: "مصطفى إسماعيل"),
        Reciter(id: "ar.saadalghamadi", name: "Saad Al-Ghamadi", arabicName: "سعد الغامدي"),
        Reciter(id: "ar.yasser", name: "Yasser Ad-Dussary", arabicName: "ياسر الدوسري"),
        Reciter(id: "ar.aymanswoaid", name: "Ayman Suwaid", arabicName: "أيمن سويد"),
        Reciter(id: "ar.abdullahawadaljuhani", name: "Abdullah Awad Al-Juhani", arabicName: "عبدالله عواد الجهني"),
        Reciter(id: "ar.waleedidrees", name: "Waleed Idrees al-Maneese", arabicName: "وليد إدريس المنيسي"),
        Reciter(id: "ar.ibrahimakhbar", name: "Ibrahim Al-Akhdar", arabicName: "إبراهيم الأخضر"),

        // Additional Quality Reciters
        Reciter(id: "ar.abdulsamad", name: "Abdul Basit Abdul Samad", arabicName: "عبد الباسط عبد الصمد"),
        Reciter(id: "ar.abdullahmatroud", name: "Abdullah Matroud", arabicName: "عبدالله مطرود"),
        Reciter(id: "ar.farsabbagh", name: "Fares Abbad", arabicName: "فارس عباد"),
        Reciter(id: "ar.islamsobhi", name: "Islam Sobhi", arabicName: "إسلام صبحي"),
    ]

    /// Default reciter (Mahmoud Khalil Al-Husary)
    public static let `default` = all.first(where: { $0.id == "ar.husary" }) ?? all[0]

    /// Find a reciter by their identifier
    public static func findById(_ id: String) -> Reciter? {
        return all.first(where: { $0.id == id })
    }
}
