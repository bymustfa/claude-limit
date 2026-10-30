# ClaudeLimit

[English](README.md) · **Türkçe**

**Claude Code** haftalık limitinin ne kadarını kullandığını gösteren, haftalık limiti günlere adil
bir pay olarak bölen küçük bir macOS menü çubuğu uygulaması.

Claude'un haftalık limiti haftada bir sıfırlanır. Yoğun iki günde limitin çoğunu bitirip haftanın
geri kalanında takılı kalmak çok kolay. ClaudeLimit haftalık yüzdeyi günlük bir bütçeye çevirir;
bugün önde mi geride mi olduğunu tek bakışta görürsün.

## Özellikler

- Menü çubuğunda `12 / 14` gibi bir yazı: bugün kullanılan yüzde / bugünkü pay.
- Haftanın her günü için bir çubuk içeren panel; üzerine gelince ayrıntılar.
- **Devirli günlük pay:** kalan haftalık bütçe kalan günlere bölünür. Bugün az kullanırsan yarının
  payı büyür, çok kullanırsan küçülür.
- Tek bakışta durum: rahatsın, paya yaklaştın ya da payı aştın.
- 5 saatlik oturum limitini ve haftanın ne zaman sıfırlanacağını da gösterir.
- İsteğe bağlı "Girişte aç".
- Türkçe ve İngilizce arayüz; macOS diline göre otomatik seçilir (diğer dillerde İngilizce).

## Nasıl çalışır

Uygulama 10 dakikada bir `claude -p "/usage"` komutunu (resmî Claude Code CLI) çalıştırır, çıktıdan
haftalık ve oturum yüzdelerini okur ve yerel bir SQLite veritabanına kaydeder. Günler yerel saatle
gece yarısı değişir; haftanın ilk ve son günü sıfırlanma saatine kadar olan farkı üstlenir. Claude
Code yüzdeyi tam sayı olarak verdiği için değerler ±1 puan sapabilir.

## Gereksinimler

- macOS 14 (Sonoma) veya üzeri.
- Kurulu ve bir Claude aboneliğiyle (Pro / Max) giriş yapılmış
  [Claude Code](https://docs.claude.com/en/docs/claude-code) — terminalde `claude` komutu çalışmalı.
- Derlemek için: Xcode 26 veya üzeri (uygulama, varsa macOS 26 cam efektini kullanır).

## Kurulum

```bash
git clone https://github.com/bymustfa/claude-limit.git
cd claude-limit
./scripts/build-app.sh
mv dist/ClaudeLimit.app /Applications/
open /Applications/ClaudeLimit.app
```

Uygulama menü çubuğunda görünür (Dock simgesi yoktur). Tıkla ve otomatik başlasın istiyorsan
**Girişte aç** seçeneğini aç.

> Xcode `/Applications/Xcode.app` konumunda değilse betiği
> `DEVELOPER_DIR=/Xcode/yolu/Xcode.app/Contents/Developer ./scripts/build-app.sh` şeklinde çalıştır.

> Uygulama ad-hoc imzalıdır, notarize edilmemiştir. macOS ilk açılışta engellerse Finder'da
> uygulamaya sağ tıklayıp **Aç**'ı seç.

## Veri ve gizlilik

- Her şey Mac'inde kalır. Uygulama kendi başına ağ isteği yapmaz; yalnızca zaten kullandığın
  `claude` CLI'ını çalıştırır.
- Veriler `~/Library/Application Support/ClaudeLimit/usage.db` dosyasında tutulur.

## Kaldırma

Uygulamadan panel üzerinden çık, sonra:

```bash
rm -rf /Applications/ClaudeLimit.app ~/Library/"Application Support"/ClaudeLimit
```

## Geliştirme

```bash
swift build
swift test
swift run ClaudeLimit   # .app paketi olmadan çalışır, arayüz yalnızca İngilizce olur
```

`xcode-select -p` Command Line Tools'u gösteriyorsa bu komutların başına
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` ekle.

Proje yapısı:

- `Sources/ClaudeLimitCore` – çözümleme, depolama ve haftalık/günlük model (birim testli).
- `Sources/ClaudeLimit` – SwiftUI menü çubuğu uygulaması.
- `Resources/*.lproj` – çeviriler; `scripts/build-app.sh` bunları uygulamanın içine kopyalar.

Issue ve pull request'ler memnuniyetle karşılanır. Yeni bir dil eklemek için
`Resources/<kod>.lproj/Localizable.strings` dosyası ekleyip dil kodunu `scripts/build-app.sh`
içindeki listeye yazman yeterli.

## Lisans

[MIT](LICENSE)

ClaudeLimit bağımsız bir projedir; Anthropic ile bir bağlantısı yoktur.
