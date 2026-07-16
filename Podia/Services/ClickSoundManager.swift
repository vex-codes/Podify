import Foundation
import AVFoundation

class ClickSoundManager {
    static let shared = ClickSoundManager()
    private var players: [AVAudioPlayer] = []
    private var currentIndex = 0
    
    private init() {
        // A generated 15ms mechanical tick/thump WAV file
        let base64String = "UklGRk4FAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YSoFAADitb67Etas3ozCAxLD7YYtrRsV6OztDEb/7e85r+zrLAocmtaf/HtRttqRK9c0BOKH/PsiFf7T8iIiLABMAHA4y+ndJP5F4QTp8QJHK0qUQ6ZP2DllFpYpYw6JKww7gi+RNt38SwJhOKERrBvgQ0dCpAR0EXEzCyifIQ05XAJEP88gsP4C9zIBQxp+M1M3RAmKMJMma0BpPAo7WyB/KJw8LTCkFYsGBPq2JwYFCwAPM2wK7QFjNZwTa/Q+9xIWvfP/GZL6hfuz/ikv1Pl4/JMqIxJn8tckM/ujCIEIP/GvHS4TShGe99AhFPSHC7f4jAyiHUMO2v7JEcv2AxElDesauAbbCxIXRwR++6QHfRO5+3X6u/oGASEXIQCrCukRAhFgCdcHj/KwEobuhf7N+D/tkQaG7k33ahC6CNX7XwwlC8DsAwMr8GX+rwegCC8DJO9LAyHv+vyCAZPuUPiq7L78hfu87ijyDf678jv8TwAy7i8Bteud70DulfGXBQnzNfOQ9NTs4/1mAIfzI//r/5Hzhf9v8BDzofHe8573//q+8bj8bQNQ++0BmgJ5/fb/bfVD/mbwevSU9fX9iPaM+kTw0vsu8g/1dvjf8nH7iv868fP1MPGc/LL61P4X83f9A/dI+q71pv/a/3T4Avr59MQBj/YN/zL25QEz+AEDKgJ7+9n2p/yuA539IwAAALP3I/pD/YT5D/5YAmn8WPhVA4D9h/dGBF4AVAOcA3AAtgTGBJD+lfwGBAAAlPzm/NT86v94A3sCKwRuAbH/HwA4/ksALwS3+58DoAKs/rj8dAURAQD+Nf4hBWYEMQS6/lAF2f21/6sEDQVo/q0BggB3/UcAvgQrAP8BaQWK/gcESwEmAFIAEAOFA4j/L/7hAcwDMAJn/uoBdQKyAR3/4wH/AAYA/gM1/+v+BP+GALwExAJ7/wEBwAKgAaQBwv8OA4ABLgEWBGgBnwKD/wQAYv8zAhUCbAEYAQwCGgIWAkcCJgLIAXAADgJXA7ACUQKzA98CAwAnAF3/VQISAGcAWv/2AogBMQJ8/0QCMAB//5n/1/9wATH/1v8IABkCEgJZAesA6AAH//gB/QEPABMB8QBkAkICL/9vAQMBtgBQARD/jgFfAB4B4ABE/xT/hwBHAZQAWwArAGkBTv9WAdH+AwAy/1f/K/8r/8v+lv4XATIAXgCcACgATwDZ/67/ov4x/8gAiv6y/zEAZQCE/zQALwBoAFAAIQDZ/1T/qADF/38Anv+8/4gAMwCZ/8P+4P/U//r+9P9dAFb/1/+U/hr/7/6E//H/9f4JAJv+sv+l/9z+LP///xD/Af85AKv+Pf8GAF3/yv6c/+L/yf4i/2b/x//f/47/xv/z/vP+Xv8U/y3/wP8b/4v/IQDE/97/aP/S/y0AE/8yAM3/MADE/67/y/9d/ycApP/+/yf/X/8vABkA3f/E/4D/Vv/e/9//4v/f/+D/tf9j/x0AEQAlABgAgf///6f/nv9o/+L/1P8LAEAAeP/4/0YA7P+I/5v/1f/w/zUAJAA5ALP/8P8yALv/kv/K/6X/KADW/xwAPAAsABEA8/9cACEA4f8eAAIARgDE/xcASQC//8X/zf/3/18AJQAeAPv//f9eAAsASAAkAAAAWwA0AGQA5v8hADIA7v8yAOP/MQALAO//PgArAOL/GQAhABUATQBcAOf/LAD1/14APQAHAB8AEgAEACwADAD+/zsAQAA3AFkA8P8vACwATgBEAP//JADz/xIAJQAGAA=="
        
        if let data = Data(base64Encoded: base64String) {
            // Create a pool of 5 players for round-robin firing to prevent audio dropouts
            for _ in 0..<5 {
                if let player = try? AVAudioPlayer(data: data) {
                    player.prepareToPlay()
                    players.append(player)
                }
            }
        }
    }
    
    func playClick() {
        guard !players.isEmpty else { return }
        let player = players[currentIndex]
        
        // Ensure it cuts off immediately and replays if needed
        if player.isPlaying {
            player.stop()
            player.currentTime = 0
        }
        
        player.play()
        currentIndex = (currentIndex + 1) % players.count
    }
}
