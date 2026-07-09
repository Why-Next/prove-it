# prove-it

[English](../../README.md) ·
[中文](README.zh.md) ·
[Deutsch](README.de.md) ·
[日本語](README.ja.md) ·
हिन्दी ·
[Français](README.fr.md) ·
[Italiano](README.it.md) ·
[Português](README.pt.md) ·
[Русский](README.ru.md) ·
[Español](README.es.md) ·
[한국어](README.ko.md)

**जब तक आपका repo खुद को साबित नहीं कर देता, आपका agent अपनी turn खत्म नहीं कर सकता।**

Coding agents "tests pass" कह देते हैं बिना उन्हें चलाए, और "fixed" कह देते हैं बिना कभी bug को reproduce किए। यह किसी बदनीयती से नहीं होता: एक agent यह नहीं बता सकता कि उसने क्या किया बनाम उसका इरादा क्या करने का था, इसलिए वह इरादे को ही रिपोर्ट कर देता है।

`prove-it` *done* को ऐसी चीज़ बना देता है जिसे agent को pass करना पड़ता है, न कि ऐसी चीज़ जिसे वह बस कह सकता है। अपने repo की root में एक `verify.sh` रखिए। जब agent रुकने की कोशिश करता है, gate उसे चलाता है। Non-zero exit हुआ, और turn खत्म नहीं होती।

```
agent: "All tests pass. Ready to merge."
       └─ tries to end turn
          └─ prove-it runs ./verify.sh
             └─ exit 1:  FAIL src/auth.test.ts  (3 failed, 41 passed)
                └─ turn blocked, agent keeps working

agent: "Actually, three tests were failing. Fixing."
```

लगभग आधी बार, जब किसी agent से सबूत माँगा जाता है तो वह जवाब देता है "you're right, it isn't done yet."

## इंस्टॉल

`bash`, `git`, `python3` चाहिए। कोई package नहीं, कोई daemon नहीं, कहीं sign up करने की ज़रूरत नहीं। इसे कहीं भी clone कर लीजिए:

```bash
git clone https://github.com/YOUR_ORG/prove-it ~/.local/share/prove-it
```

[`hooks/settings.example.json`](../../hooks/settings.example.json) को अपनी `.claude/settings.json` (per repo) या `~/.claude/settings.json` (everywhere) में merge करके दोनों hooks को Claude Code में जोड़ दीजिए।

फिर वही एक फाइल लिखिए जो असल में मायने रखती है:

```bash
cat > verify.sh <<'EOF'
#!/bin/bash
set -eu
cd "$(dirname "$0")"

npm test
npx tsc --noEmit
git diff --check

echo "verify.sh OK"
EOF
chmod +x verify.sh
```

बस इतना ही setup है। आपके repo में अभी कोई `verify.sh` नहीं है, इसलिए जब तक आप एक नहीं लिखते, gate कुछ भी नहीं करता।

## आपके पहले पाँच मिनट

जितना आप सोचते हैं उससे छोटा शुरू कीजिए। एक `verify.sh` जो सिर्फ `git diff --check` चलाता है, वह भी रखने लायक है, और वह pass होगा, जो आपको सिखाता है कि जब सब ठीक है तब gate चुप रहता है।

```bash
printf '#!/bin/bash\nset -eu\ncd "$(dirname "$0")"\ngit diff --check\n' > verify.sh
chmod +x verify.sh
./verify.sh                 # run it yourself first. Never ship a check you have not seen pass.
```

अब इसे जानबूझकर fail होते देखिए, ताकि आप जान लें कि gate असली है:

```bash
sed -i.bak 's|git diff --check|git diff --check\nexit 1|' verify.sh && rm verify.sh.bak
```

अपने agent से किसी भी फाइल को edit करने को कहिए, फिर उसे खत्म करने दीजिए। वह अपनी turn खत्म करने की कोशिश करेगा, gate `verify.sh` चलाएगा, और turn block हो जाएगी। `exit 1` को undo कर दीजिए और वही agent बिना रुके निकल जाएगा।

वहाँ से, एक बार में एक असली check जोड़िए: वह test command जो आप सचमुच चलाते हैं, फिर type checker, फिर diff hygiene। हर check जो आप जोड़ते हैं, वह *proven का यहाँ क्या मतलब है* इसके आपके जवाब का एक वाक्य है। जब पूरी चीज़ में करीब एक मिनट लगने लगे, तब रुक जाइए।

बचने वाली गलती यह है कि पहले ही दिन एक महत्वाकांक्षी `verify.sh` लिख डालना। एक धीमा या flaky gate एक हफ्ते के भीतर bypass कर दिया जाता है, और एक bypass किया गया gate किसी gate न होने से बुरा है: यह आपको बताता है कि एक check हुआ जबकि हुआ ही नहीं।

## यह चलने का फैसला कैसे करता है

Gate by default चुप रहता है। यह `verify.sh` तभी चलाता है जब इनमें से हर एक बात सच हो:

- session ने सचमुच फाइलें edit कीं (एक read-only session के पास साबित करने को कुछ नहीं है)
- repo की root में एक executable `verify.sh` मौजूद है
- working tree में uncommitted changes हैं
- यह exact tree state पहले से pass नहीं हुई है

आखिरी बात का मतलब है कि एक pass होने वाली tree एक बार verify होती है, हर stop पर नहीं। Failures agent को output की आखिरी 20 lines print करती हैं, जो आमतौर पर बिना बताए ही उसके लिए कारण ठीक करने को काफी होती हैं।

Gate को जानबूझकर पार करने के लिए: `PROVE_IT_SKIP=1`। इसे हमेशा के लिए बंद करने के लिए: `verify.sh` को delete कर दीजिए। दोनों जानबूझकर किए जाने वाले काम हैं। एक ऐसा gate जिसे कोई हटा न सके, वह ऐसा gate है जिसके इर्द-गिर्द लोग रास्ता निकाल लेते हैं।

## बाहर निकलना ही फीचर है

सबसे कठिन failure mode कोई flaky check नहीं है। यह एक ऐसा agent है जो `verify.sh` को pass नहीं कर पाता और चुपके से `verify.sh` को ही edit कर देता है। Gate का failure message यह साफ शब्दों में कहता है, और spec इसे एक घोषित violation बनाता है। फिर भी अपने diffs में इस पर नज़र रखिए। diff evidence इसी के लिए है।

## `verify.sh` कन्वेंशन

`hooks/` में मौजूद script जानबूझकर छोटी है। असली artifact वह convention है जिसे यह लागू करती है, जो **[SPEC.md](../../SPEC.md)** में लिखी गई है: एक repository घोषित करता है कि वह खुद को कैसे साबित करता है, एक ज्ञात जगह पर, एक ज्ञात contract के साथ, और एक agent तब तक completion का दावा नहीं कर सकता जब तक वह proof pass न हो जाए।

spec को पढ़िए उन चार तरह के evidence के लिए जिनके खिलाफ एक `verify.sh` को assert करना चाहिए - command output, diff, reproduction, cross-check - और conformance levels के लिए।

**शुरू में एक ईमानदार बात।** यह tool ठीक एक चीज़ लागू करता है: कि turn खत्म होने से पहले `verify.sh` ने zero return किया। उस zero का *मतलब* कुछ है या नहीं, यह पूरी तरह उन checks पर निर्भर करता है जो आपने लिखे। एक `verify.sh` जिसमें सिर्फ `exit 0` है, वह इस gate को pass कर देगा और कुछ भी साबित नहीं करेगा। Tool Level 1 है। Evidence Level 2 है, और Level 2 एक practice है, कोई feature नहीं।

## रेसिपी

हर stack के लिए शुरुआती बिंदु, [`recipes/`](../../recipes/) में। एक को `verify.sh` में copy कीजिए और जो लागू न हो उसे काट दीजिए। इसे एक मिनट के भीतर रखिए; धीमे checks CI में होने चाहिए।

| | |
|---|---|
| [`node.sh`](../../recipes/node.sh) | tests, typecheck, lint, diff hygiene |
| [`python.sh`](../../recipes/python.sh) | pytest, ruff, mypy |
| [`go.sh`](../../recipes/go.sh) | go test, vet, gofmt check |
| [`flutter.sh`](../../recipes/flutter.sh) | analyze, test, format check |

इसे अपनाने का कठिन हिस्सा कभी hook को wire करना नहीं होता। यह पहली बार "इस repo में *proven* का क्या मतलब है" इसका जवाब देना होता है।

## बहीखाता

`PROVE_IT_LEDGER=1` set कीजिए और पकड़ा गया हर false completion `~/.prove-it/ledger.jsonl` में एक line जोड़ता है:

```json
{"ts":"2026-07-09T04:12:33Z","claim":"All tests pass. Ready to merge.",
 "evidence_demanded":"verify.sh exit 0","actual":["3 failed, 41 passed"]}
```

क्या दावा किया गया, क्या माँगा गया, क्या सच था। सिर्फ local disk पर, कभी transmit नहीं होता, तब तक बंद रहता है जब तक आप इसे चालू न करें। एक महीने बाद आप यह अंदाज़ा लगाना बंद कर देते हैं कि आपका agent कैसे fail होता है और उसे पढ़ना शुरू कर देते हैं।

## यह रिपो खुद को गेट करता है

`prove-it` के पास एक `verify.sh` है, और यह gate को असली git repos के खिलाफ एक temp directory में चलाता है: fail होने वाला check block करता है, pass होने वाला check allow करता है, read-only session अछूता रहता है, clean tree skip हो जाती है, bypass काम करता है।

```bash
./verify.sh
```

वरना इसे ship करना एक अजीब बात होती।

## लाइसेंस

MIT.
