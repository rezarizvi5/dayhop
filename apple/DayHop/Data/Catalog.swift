import Foundation
import UIKit

enum Catalog {
    static let characters: [(id: String, name: String, hex: String)] = [
        ("pip", "Pip", "#1F2DE6"),
        ("bo", "Bo", "#D4552A"),
        ("juniper", "Juniper", "#2F7D4A"),
    ]

    static let accents = ["#1F2DE6", "#D4552A", "#2F7D4A", "#B45309", "#0F6E8C", "#7A3E12", "#3F4C6B", "#8A3D55"]

    static let weekdayTemplateDays = 1 | 2 | 4 | 8 | 16
    static let allWeek = 127

    static func character(id: String) -> (id: String, name: String, hex: String) {
        characters.first { $0.id == id } ?? characters[0]
    }

    static func templates() -> [Routine] {
        [
            template(name: "Morning", time: .morning, days: weekdayTemplateDays, steps: [
                ("Get up and make bed", "bed"),
                ("Brush teeth", "toothbrush"),
                ("Get dressed", "shirt"),
                ("Eat breakfast", "bowl"),
                ("Pack school bag", "bag"),
                ("Shoes on", "shoe"),
            ]),
            template(name: "After School", time: .afternoon, days: weekdayTemplateDays, steps: [
                ("Unpack bag", "bag"),
                ("Snack and water", "apple"),
                ("Homework or reading", "book"),
                ("Tidy up", "basket"),
            ]),
            template(name: "Bedtime", time: .evening, days: allWeek, steps: [
                ("Tidy toys", "blocks"),
                ("Bath or wash", "bath"),
                ("Pajamas on", "moon"),
                ("Brush teeth", "toothbrush"),
                ("Read a book", "book"),
                ("Lights out", "moon"),
            ]),
            template(name: "Chores starter", time: .custom, days: 32 | 64, steps: [
                ("Set the table", "plate"),
                ("Feed the pet", "paw"),
                ("Put laundry away", "shirt"),
                ("Tidy your room", "basket"),
                ("Take out the trash", "bin"),
            ]),
        ]
    }

    private static func template(name: String, time: TimeOfDay, days: Int, steps: [(String, String)]) -> Routine {
        Routine(
            id: UUID(),
            name: name,
            timeOfDay: time,
            days: days,
            startTime: nil,
            requiresApproval: false,
            bonusStars: 3,
            version: 1,
            createdAt: Date(),
            archivedAt: nil,
            kidIDs: [],
            inactiveKidIDs: [],
            steps: steps.enumerated().map { index, step in
                Step(id: UUID(), title: step.0, iconKey: step.1, stars: 1, position: index, timerMinutes: nil, archived: false)
            }
        )
    }
}

struct IconSpec: Identifiable {
    var key: String
    var symbol: String
    var fallback: String
    var words: String
    var id: String { key }
}

enum IconCatalog {
    static let all: [IconSpec] = [
        IconSpec(key: "bed", symbol: "bed.double.fill", fallback: "bed.double", words: "bed sleep wake"),
        IconSpec(key: "toothbrush", symbol: "toothbrush", fallback: "mouth", words: "teeth brush hygiene"),
        IconSpec(key: "shirt", symbol: "tshirt.fill", fallback: "tshirt", words: "clothes dress laundry"),
        IconSpec(key: "bowl", symbol: "cup.and.saucer.fill", fallback: "fork.knife", words: "breakfast food eat"),
        IconSpec(key: "bag", symbol: "backpack.fill", fallback: "bag", words: "school pack bag"),
        IconSpec(key: "shoe", symbol: "shoe.2.fill", fallback: "figure.walk", words: "shoes feet"),
        IconSpec(key: "apple", symbol: "fork.knife", fallback: "leaf.fill", words: "snack water food apple"),
        IconSpec(key: "book", symbol: "book.fill", fallback: "book", words: "read homework book"),
        IconSpec(key: "basket", symbol: "basket.fill", fallback: "tray.fill", words: "tidy toys room"),
        IconSpec(key: "bath", symbol: "bathtub.fill", fallback: "drop.fill", words: "bath wash"),
        IconSpec(key: "moon", symbol: "moon.stars.fill", fallback: "moon.fill", words: "bedtime pajamas lights"),
        IconSpec(key: "plate", symbol: "fork.knife", fallback: "circle.fill", words: "table meal plate"),
        IconSpec(key: "paw", symbol: "pawprint.fill", fallback: "hare.fill", words: "pet feed"),
        IconSpec(key: "bin", symbol: "trash.fill", fallback: "trash", words: "trash chores"),
        IconSpec(key: "hands", symbol: "hands.sparkles.fill", fallback: "hand.raised.fill", words: "wash soap hands"),
        IconSpec(key: "sun", symbol: "sun.max.fill", fallback: "sun.max", words: "morning outside"),
        IconSpec(key: "blocks", symbol: "cube.fill", fallback: "square.fill", words: "toys blocks play"),
        IconSpec(key: "water", symbol: "drop.fill", fallback: "drop", words: "water drink"),
        IconSpec(key: "soap", symbol: "bubbles.and.sparkles.fill", fallback: "sparkles", words: "soap wash"),
        IconSpec(key: "comb", symbol: "comb.fill", fallback: "person.fill", words: "hair comb"),
        IconSpec(key: "toilet", symbol: "toilet.fill", fallback: "house.fill", words: "toilet bathroom"),
        IconSpec(key: "shower", symbol: "shower.fill", fallback: "drop.fill", words: "shower wash"),
        IconSpec(key: "towel", symbol: "rectangle.fill", fallback: "square.fill", words: "towel dry"),
        IconSpec(key: "pajamas", symbol: "moon.fill", fallback: "bed.double", words: "pajamas night"),
        IconSpec(key: "socks", symbol: "shoeprints.fill", fallback: "figure.walk", words: "socks feet"),
        IconSpec(key: "jacket", symbol: "cloud.fill", fallback: "tshirt", words: "jacket coat outside"),
        IconSpec(key: "hat", symbol: "sun.max.fill", fallback: "circle.fill", words: "hat sun"),
        IconSpec(key: "breakfast", symbol: "sunrise.fill", fallback: "sun.max", words: "breakfast morning"),
        IconSpec(key: "lunch", symbol: "takeoutbag.and.cup.and.straw.fill", fallback: "bag.fill", words: "lunch food"),
        IconSpec(key: "dinner", symbol: "fork.knife.circle.fill", fallback: "fork.knife", words: "dinner meal"),
        IconSpec(key: "snack", symbol: "birthday.cake.fill", fallback: "star.fill", words: "snack treat"),
        IconSpec(key: "fruit", symbol: "leaf.fill", fallback: "leaf", words: "fruit food"),
        IconSpec(key: "milk", symbol: "cup.and.saucer.fill", fallback: "drop.fill", words: "milk drink"),
        IconSpec(key: "vitamins", symbol: "pills.fill", fallback: "cross.case.fill", words: "vitamins medicine"),
        IconSpec(key: "homework", symbol: "pencil", fallback: "book", words: "homework school"),
        IconSpec(key: "reading", symbol: "text.book.closed.fill", fallback: "book.fill", words: "reading book"),
        IconSpec(key: "music", symbol: "music.note", fallback: "speaker.wave.2.fill", words: "music practice"),
        IconSpec(key: "piano", symbol: "pianokeys", fallback: "music.note", words: "piano practice"),
        IconSpec(key: "sport", symbol: "sportscourt.fill", fallback: "figure.walk", words: "sport play outside"),
        IconSpec(key: "bike", symbol: "bicycle", fallback: "figure.walk", words: "bike ride"),
        IconSpec(key: "ball", symbol: "soccerball", fallback: "circle.fill", words: "ball play"),
        IconSpec(key: "draw", symbol: "paintbrush.fill", fallback: "pencil", words: "draw art"),
        IconSpec(key: "puzzle", symbol: "puzzlepiece.fill", fallback: "square.fill", words: "puzzle play"),
        IconSpec(key: "screen", symbol: "ipad", fallback: "rectangle.fill", words: "screen tablet"),
        IconSpec(key: "tidy", symbol: "sparkles", fallback: "star", words: "tidy clean"),
        IconSpec(key: "room", symbol: "house.fill", fallback: "house", words: "room home"),
        IconSpec(key: "laundry", symbol: "washer.fill", fallback: "tshirt.fill", words: "laundry clothes"),
        IconSpec(key: "dishes", symbol: "sink.fill", fallback: "drop.fill", words: "dishes wash"),
        IconSpec(key: "table", symbol: "table.furniture.fill", fallback: "square.fill", words: "table set"),
        IconSpec(key: "trash", symbol: "trash.circle.fill", fallback: "trash.fill", words: "trash out"),
        IconSpec(key: "recycle", symbol: "arrow.3.trianglepath", fallback: "arrow.triangle.2.circlepath", words: "recycle"),
        IconSpec(key: "pet", symbol: "dog.fill", fallback: "pawprint.fill", words: "dog pet"),
        IconSpec(key: "cat", symbol: "cat.fill", fallback: "pawprint.fill", words: "cat pet"),
        IconSpec(key: "fish", symbol: "fish.fill", fallback: "drop.fill", words: "fish pet"),
        IconSpec(key: "plant", symbol: "leaf.circle.fill", fallback: "leaf.fill", words: "plant water"),
        IconSpec(key: "mail", symbol: "envelope.fill", fallback: "tray.fill", words: "mail letters"),
        IconSpec(key: "backpack", symbol: "backpack", fallback: "bag", words: "backpack school"),
        IconSpec(key: "bus", symbol: "bus.fill", fallback: "car.fill", words: "bus school"),
        IconSpec(key: "car", symbol: "car.fill", fallback: "car", words: "car ride"),
        IconSpec(key: "walk", symbol: "figure.walk", fallback: "shoeprints.fill", words: "walk outside"),
        IconSpec(key: "clock", symbol: "clock.fill", fallback: "clock", words: "time clock"),
        IconSpec(key: "alarm", symbol: "alarm.fill", fallback: "clock.fill", words: "alarm wake"),
        IconSpec(key: "calendar", symbol: "calendar", fallback: "clock", words: "day calendar"),
        IconSpec(key: "star", symbol: "star.fill", fallback: "star", words: "star reward"),
        IconSpec(key: "heart", symbol: "heart.fill", fallback: "heart", words: "heart kind"),
        IconSpec(key: "smile", symbol: "face.smiling", fallback: "sun.max", words: "smile kind"),
        IconSpec(key: "hug", symbol: "figure.2.arms.open", fallback: "person.2.fill", words: "hug family"),
        IconSpec(key: "pray", symbol: "hands.clap.fill", fallback: "hands.sparkles", words: "quiet thanks"),
        IconSpec(key: "story", symbol: "book.closed.fill", fallback: "book.fill", words: "story read"),
        IconSpec(key: "lights", symbol: "lightbulb.fill", fallback: "moon.fill", words: "lights out"),
        IconSpec(key: "window", symbol: "window.vertical.open", fallback: "rectangle", words: "window air"),
        IconSpec(key: "bedmake", symbol: "bed.double", fallback: "square.fill", words: "make bed"),
        IconSpec(key: "pillow", symbol: "cloud.fill", fallback: "bed.double", words: "pillow bed"),
        IconSpec(key: "blanket", symbol: "rectangle.compress.vertical", fallback: "bed.double", words: "blanket bed"),
        IconSpec(key: "brushhair", symbol: "comb", fallback: "person.fill", words: "hair brush"),
        IconSpec(key: "facewash", symbol: "face.smiling.inverse", fallback: "drop.fill", words: "face wash"),
        IconSpec(key: "sunscreen", symbol: "sun.max.circle.fill", fallback: "sun.max.fill", words: "sunscreen outside"),
        IconSpec(key: "medicine", symbol: "cross.case.fill", fallback: "cross.fill", words: "medicine"),
        IconSpec(key: "inhaler", symbol: "lungs.fill", fallback: "wind", words: "inhaler breath"),
        IconSpec(key: "glasses", symbol: "eyeglasses", fallback: "eye", words: "glasses"),
        IconSpec(key: "hearing", symbol: "ear", fallback: "speaker.wave.1", words: "hearing ears"),
        IconSpec(key: "mask", symbol: "facemask.fill", fallback: "mouth", words: "mask"),
        IconSpec(key: "tissue", symbol: "wind", fallback: "cloud", words: "tissue nose"),
        IconSpec(key: "potty", symbol: "figure.stand", fallback: "person.fill", words: "potty toilet"),
        IconSpec(key: "diaper", symbol: "square.dashed", fallback: "square", words: "diaper change"),
        IconSpec(key: "bottle", symbol: "waterbottle.fill", fallback: "drop.fill", words: "bottle water"),
        IconSpec(key: "lunchbox", symbol: "shippingbox.fill", fallback: "bag.fill", words: "lunchbox school"),
        IconSpec(key: "homeworkbag", symbol: "studentdesk", fallback: "book.fill", words: "desk homework"),
        IconSpec(key: "folder", symbol: "folder.fill", fallback: "folder", words: "folder papers"),
        IconSpec(key: "crayon", symbol: "paintpalette.fill", fallback: "pencil", words: "crayon art"),
        IconSpec(key: "scissors", symbol: "scissors", fallback: "pencil", words: "scissors craft"),
        IconSpec(key: "glue", symbol: "paperclip", fallback: "square.fill", words: "glue craft"),
        IconSpec(key: "instrument", symbol: "guitars.fill", fallback: "music.note", words: "music instrument"),
        IconSpec(key: "song", symbol: "music.mic", fallback: "music.note", words: "song sing"),
        IconSpec(key: "dance", symbol: "figure.dance", fallback: "figure.walk", words: "dance play"),
        IconSpec(key: "stretch", symbol: "figure.flexibility", fallback: "figure.walk", words: "stretch body"),
        IconSpec(key: "run", symbol: "figure.run", fallback: "figure.walk", words: "run outside"),
        IconSpec(key: "swim", symbol: "figure.pool.swim", fallback: "drop.fill", words: "swim bath"),
        IconSpec(key: "park", symbol: "tree.fill", fallback: "leaf.fill", words: "park outside"),
        IconSpec(key: "garden", symbol: "camera.macro", fallback: "leaf.fill", words: "garden flower"),
        IconSpec(key: "dogwalk", symbol: "dog", fallback: "pawprint", words: "walk dog"),
        IconSpec(key: "feed", symbol: "fork.knife", fallback: "pawprint.fill", words: "feed pet"),
        IconSpec(key: "litter", symbol: "trash", fallback: "pawprint", words: "litter pet"),
        IconSpec(key: "vacuum", symbol: "fanblades.fill", fallback: "wind", words: "vacuum clean"),
        IconSpec(key: "sweep", symbol: "broom", fallback: "sparkles", words: "sweep floor"),
        IconSpec(key: "mop", symbol: "humidity.fill", fallback: "drop.fill", words: "mop floor"),
        IconSpec(key: "dust", symbol: "sparkle", fallback: "sparkles", words: "dust tidy"),
        IconSpec(key: "toys", symbol: "gamecontroller.fill", fallback: "cube.fill", words: "toys away"),
        IconSpec(key: "books", symbol: "books.vertical.fill", fallback: "book.fill", words: "books shelf"),
        IconSpec(key: "clothes", symbol: "tshirt", fallback: "square.fill", words: "clothes away"),
        IconSpec(key: "hamper", symbol: "archivebox.fill", fallback: "tray.fill", words: "hamper laundry"),
        IconSpec(key: "fold", symbol: "rectangle.split.2x1", fallback: "tshirt", words: "fold clothes"),
        IconSpec(key: "shoesaway", symbol: "shoeprints.fill", fallback: "figure.walk", words: "shoes away"),
        IconSpec(key: "door", symbol: "door.left.hand.open", fallback: "house", words: "door lock"),
        IconSpec(key: "keys", symbol: "key.fill", fallback: "key", words: "keys"),
        IconSpec(key: "lightsout", symbol: "lightswitch.off", fallback: "moon.fill", words: "lights off"),
        IconSpec(key: "storytime", symbol: "quote.bubble.fill", fallback: "book.fill", words: "story time"),
        IconSpec(key: "praybed", symbol: "moon.zzz.fill", fallback: "moon.fill", words: "quiet bed"),
        IconSpec(key: "sleep", symbol: "powersleep", fallback: "bed.double.fill", words: "sleep bed"),
        IconSpec(key: "kiss", symbol: "heart.circle.fill", fallback: "heart.fill", words: "goodnight kiss"),
        IconSpec(key: "plush", symbol: "teddybear.fill", fallback: "heart.fill", words: "plush toy"),
        IconSpec(key: "nightlight", symbol: "lamp.desk.fill", fallback: "lightbulb", words: "night light"),
        IconSpec(key: "journal", symbol: "square.and.pencil", fallback: "pencil", words: "journal write"),
        IconSpec(key: "gratitude", symbol: "sun.and.horizon.fill", fallback: "sun.max", words: "gratitude day"),
        IconSpec(key: "chorechart", symbol: "checklist", fallback: "list.bullet", words: "chores list"),
        IconSpec(key: "timer", symbol: "timer", fallback: "clock.fill", words: "timer wait"),
        IconSpec(key: "bell", symbol: "bell.fill", fallback: "bell", words: "bell remind"),
        IconSpec(key: "flag", symbol: "flag.fill", fallback: "flag", words: "done flag"),
        IconSpec(key: "medal", symbol: "medal.fill", fallback: "star.fill", words: "medal reward"),
        IconSpec(key: "gift", symbol: "gift.fill", fallback: "star.fill", words: "gift reward"),
        IconSpec(key: "movie", symbol: "film.fill", fallback: "play.rectangle.fill", words: "movie reward"),
        IconSpec(key: "parktrip", symbol: "figure.play", fallback: "figure.walk", words: "park reward"),
        IconSpec(key: "icecream", symbol: "snowflake", fallback: "star.fill", words: "treat reward"),
        IconSpec(key: "friend", symbol: "person.2.fill", fallback: "person.fill", words: "friend play"),
        IconSpec(key: "grandma", symbol: "figure.wave", fallback: "person.fill", words: "family call"),
        IconSpec(key: "phone", symbol: "phone.fill", fallback: "phone", words: "call family"),
        IconSpec(key: "photo", symbol: "photo.fill", fallback: "rectangle", words: "photo"),
        IconSpec(key: "camera", symbol: "camera.fill", fallback: "camera", words: "camera"),
        IconSpec(key: "nature", symbol: "mountain.2.fill", fallback: "leaf.fill", words: "outside nature"),
        IconSpec(key: "rain", symbol: "cloud.rain.fill", fallback: "cloud.fill", words: "rain coat"),
        IconSpec(key: "snow", symbol: "snowflake", fallback: "cloud.snow.fill", words: "snow cold"),
        IconSpec(key: "umbrella", symbol: "umbrella.fill", fallback: "cloud.rain", words: "umbrella"),
        IconSpec(key: "boots", symbol: "shoe.2", fallback: "figure.walk", words: "boots shoes"),
        IconSpec(key: "gloves", symbol: "hand.raised.fill", fallback: "hand.raised", words: "gloves cold"),
        IconSpec(key: "scarf", symbol: "wind", fallback: "tshirt", words: "scarf cold"),
        IconSpec(key: "breakfastbowl", symbol: "bowl.fill", fallback: "fork.knife", words: "bowl cereal"),
        IconSpec(key: "cereal", symbol: "cup.and.saucer", fallback: "fork.knife", words: "cereal breakfast"),
        IconSpec(key: "toast", symbol: "flame.fill", fallback: "fork.knife", words: "toast breakfast"),
        IconSpec(key: "sandwich", symbol: "takeoutbag.and.cup.and.straw", fallback: "bag", words: "sandwich lunch"),
        IconSpec(key: "vegetables", symbol: "carrot.fill", fallback: "leaf.fill", words: "vegetables dinner"),
        IconSpec(key: "soup", symbol: "mug.fill", fallback: "cup.and.saucer", words: "soup dinner"),
        IconSpec(key: "brushhair2", symbol: "person.crop.circle", fallback: "person.fill", words: "hair ready"),
        IconSpec(key: "nails", symbol: "hand.point.up.fill", fallback: "hand.raised", words: "nails wash"),
        IconSpec(key: "floss", symbol: "mouth.fill", fallback: "mouth", words: "floss teeth"),
        IconSpec(key: "rinse", symbol: "spigot.fill", fallback: "drop.fill", words: "rinse water"),
        IconSpec(key: "packlunch", symbol: "bag.fill", fallback: "backpack", words: "pack lunch"),
        IconSpec(key: "permission", symbol: "doc.text.fill", fallback: "folder", words: "paper school"),
        IconSpec(key: "library", symbol: "building.columns.fill", fallback: "book.fill", words: "library books"),
        IconSpec(key: "practice", symbol: "metronome.fill", fallback: "music.note", words: "practice music"),
        IconSpec(key: "spell", symbol: "textformat.abc", fallback: "pencil", words: "spelling homework"),
        IconSpec(key: "math", symbol: "plus.forwardslash.minus", fallback: "pencil", words: "math homework"),
        IconSpec(key: "quiettime", symbol: "speaker.slash.fill", fallback: "moon", words: "quiet rest"),
        IconSpec(key: "rest", symbol: "powersleep", fallback: "bed.double", words: "rest nap"),
        IconSpec(key: "outside", symbol: "sun.min.fill", fallback: "sun.max", words: "outside play"),
        IconSpec(key: "sandbox", symbol: "square.stack.3d.up.fill", fallback: "cube.fill", words: "sandbox play"),
        IconSpec(key: "blocksaway", symbol: "shippingbox", fallback: "cube", words: "blocks away"),
        IconSpec(key: "lego", symbol: "square.grid.3x3.fill", fallback: "square.fill", words: "bricks toys"),
        IconSpec(key: "doll", symbol: "figure.stand.dress", fallback: "person.fill", words: "doll toys"),
        IconSpec(key: "train", symbol: "tram.fill", fallback: "car.fill", words: "train toys"),
        IconSpec(key: "coloring", symbol: "paintbrush.pointed.fill", fallback: "pencil", words: "coloring art"),
        IconSpec(key: "cleanup", symbol: "checkmark.circle.fill", fallback: "sparkles", words: "cleanup tidy"),
        IconSpec(key: "helper", symbol: "person.fill.checkmark", fallback: "person.fill", words: "help family"),
        IconSpec(key: "please", symbol: "bubble.left.fill", fallback: "text.bubble", words: "please words"),
        IconSpec(key: "thanks", symbol: "hands.clap", fallback: "heart", words: "thanks kind"),
        IconSpec(key: "share", symbol: "square.and.arrow.up", fallback: "person.2", words: "share toys"),
        IconSpec(key: "wait", symbol: "hourglass", fallback: "clock", words: "wait turn"),
        IconSpec(key: "breathe", symbol: "wind", fallback: "lungs", words: "breathe calm"),
        IconSpec(key: "yoga", symbol: "figure.mind.and.body", fallback: "figure.walk", words: "stretch calm"),
    ]

    static func spec(_ key: String) -> IconSpec {
        all.first { $0.key == key } ?? all[0]
    }

    static func symbol(for key: String) -> String {
        let item = spec(key)
        if UIImage(systemName: item.symbol) != nil { return item.symbol }
        if UIImage(systemName: item.fallback) != nil { return item.fallback }
        return "circle.fill"
    }

    static func search(_ query: String) -> [IconSpec] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return all }
        return all.filter {
            $0.key.contains(needle) || $0.words.contains(needle) || $0.symbol.contains(needle)
        }
    }
}
