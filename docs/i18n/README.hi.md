# prove-it

[![verify](https://github.com/Why-Next/prove-it/actions/workflows/verify.yml/badge.svg)](https://github.com/Why-Next/prove-it/actions/workflows/verify.yml)
[![spec 0.1](https://img.shields.io/badge/spec-0.1-4F6134)](../../SPEC.md)
[![license MIT](https://img.shields.io/badge/license-MIT-lightgrey)](../../LICENSE)
![dependencies none](https://img.shields.io/badge/dependencies-none-4F6134)

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

आपका agent अपनी turn तब तक समाप्त नहीं कर सकता जब तक आपकी repository खुद को साबित न कर दे।

Coding agent बताते हैं कि tests pass हो गए, जबकि उन्होंने उन्हें कभी चलाया ही नहीं, और यह कि कोई bug ठीक हो गया, जबकि उन्होंने उसे कभी reproduce ही नहीं किया। agent के पास इसकी तुलना करने का कोई तरीका नहीं है कि उसने क्या किया बनाम उसका इरादा क्या था, इसलिए वह इरादे की रिपोर्ट कर देता है। यह एक design गुण है, कोई चारित्रिक दोष नहीं, और कोई भी prompt इसे ठीक नहीं करता।

`prove-it` उस रिपोर्ट को एक check में बदल देता है। अपनी repository की root पर एक `verify.sh` रखें। जब agent अपनी turn समाप्त करने की कोशिश करता है, तो एक hook उस script को चलाता है, और एक non-zero exit agent को रुकने देने के बजाय वापस काम पर भेज देता है।

![prove-it उस agent को block करता है जो दावा करता है कि वह पूरा कर चुका है](../../docs/demo.svg)

gate एक turn में तीन बार तक वापस धकेलता है और फिर हार मान लेता है, क्योंकि जो hook कभी हार नहीं मानता वह session को अटका देता है। हार मानना pass होने जैसा नहीं है, इसलिए आखिर में आप "done" शब्द के बजाय एक चेतावनी देखते हैं कि turn बिना verify हुए समाप्त हो गई। तीन एक ऐसी संख्या है जिसे आप बदल सकते हैं, और इसमें से कुछ भी यह दावा नहीं है कि आपका agent gate को पार नहीं कर सकता। यह यह दावा है कि वह gate को चुपचाप पार नहीं कर सकता।

इसे तब इस्तेमाल करें जब repository में कोई local command हो जो agent के काम लौटाने से पहले सच होनी चाहिए: tests, type checks, lint, generated-file checks, migration dry runs, या छोटा smoke test जो साबित करे कि bug चला गया। `prove-it` उन repositories में सबसे उपयोगी है जहाँ agent code edit करता है और उसी thread में "done" कहता है।

इसे sandbox, CI replacement, या लंबे network jobs की जगह के रूप में इस्तेमाल न करें। अगर किसी check को secrets, production access, या लगभग एक minute से ज़्यादा समय चाहिए, तो उसे CI में रखें और `verify.sh` में वही local proof रखें जिसे agent काम करते समय चला सके।

पहले दिन का flow जानबूझकर छोटा है। Plugin install करें, `/prove-it:init` चलाएँ, generated `git diff --check` को ही active check रहने दें, फिर एक real command को हाथ से pass होते देखने के बाद चालू करें। इसके बाद agent repository बदलकर रुकना चाहे, तो `verify.sh` तय करता है कि वह काम वापस दे सकता है या नहीं।

## अपनी खुद की पाँच lines क्यों नहीं?

एक Stop hook जो आपके tests चलाता है, bash की पाँच lines है, ज़्यादातर लोगों का पहला version यही होता है, और यह चार चुपचाप तरीकों से fail होता है। इनमें से कई इसी gate के शुरुआती versions में bugs थे, इसीलिए अब हर एक के लिए एक regression test है।

- **यह एक बार वापस धकेलता है, फिर कभी नहीं।** Claude Code पहले block के बाद हर stop पर `stop_hook_active` सेट कर देता है। जो hook उस flag को "जाने दो" के रूप में पढ़ता है वह ठीक एक बार block करता है और फिर gate रहना बंद कर देता है, और जो उस flag को नज़रअंदाज़ करता है वह हमेशा block करता रहता है और session को अटका देता है। यह gate प्रयासों को गिनता है, एक सीमित संख्या में बार वापस धकेलता है, और फिर ज़ोर से हार मान लेता है।
- **एक commit ऐसा दिखता है जैसे कुछ हुआ ही नहीं।** जो hook यह देखकर फैसला करता है कि working tree गंदी है या नहीं, वह हर उस turn को गुज़र जाने देता है जो commit पर समाप्त होती है, और commit करना agent का सबसे साधारण काम है। यह gate tree की तुलना session की शुरुआत में दर्ज baseline से करता है, इसलिए एक commit, `sed` से किया गया rewrite, और एक generated file - ये सब बदलाव गिने जाते हैं।
- **agent check को ही हटा सकता है।** जो agent `verify.sh` को pass नहीं करा पाता, वह इसके बजाय उसे delete या `chmod -x` कर सकता है। यह gate दर्ज कर लेता है कि session शुरू होते समय repository armed थी या नहीं, और ऐसी turn को अस्वीकार कर देता है जो gate के निहत्थे रहते समाप्त होती है। ऐसा rewrite जो उसे executable बनाए रखता है, गुज़रने दिया जाता है, और उस पर चुपचाप भरोसा करने के बजाय आपको उसकी रिपोर्ट दी जाती है।
- **हार मानना pass होने से अलग नहीं पहचाना जा सकता।** हर host आखिरकार किसी hook को हार मानने पर मजबूर कर देता है। हाथ से लिखा hook चुपचाप हार मानता है और आखिरी शब्द जो आप देखते हैं वह "done" होता है; इस वाले का आखिरी शब्द एक चेतावनी है कि turn बिना verify हुए समाप्त हो गई।

अगर आप अपना ही hook रखना पसंद करें, तो उसे रखें, और उन cases के लिए [SPEC.md](../../SPEC.md) पढ़ें जिन्हें उसे कवर करना ही होगा। convention उसके इस implementation से ज़्यादा मायने रखता है।

## इंस्टॉल

तीन lines, और असल काम तीसरी करती है:

```
/plugin marketplace add Why-Next/prove-it
/plugin install prove-it@whynext
/prove-it:init
```

`/prove-it:init` आपके stack का पता लगाता है, एक `verify.sh` लिखता है, उसे चलाता है ताकि आप उसे pass होते देखें, फिर एक copy चलाता है जिसके अंत में `exit 1` जोड़ा गया हो ताकि आप gate को एक turn अस्वीकार करते देखें। इसमें लगभग तीस सेकंड लगते हैं और यह कभी आपके पहले से मौजूद `verify.sh` को overwrite नहीं करता।

तैयार किए गए gate में ठीक एक active check होता है, `git diff --check`, और आपके stack के लिए checks comments के रूप में लिखे रहते हैं। यह जिस दिन आप इसे install करते हैं उसी दिन pass होता है, जान-बूझकर। जो gate उतरने के दिन ही `main` पर fail होता है, वह लोगों को पहले ही हफ्ते में उसे bypass करना सिखा देता है। commented checks को एक-एक करके चालू करें, हर एक को अपने हाथ से pass होते देख लेने के बाद।

और कुछ भी configure नहीं होता, और जब तक कोई `verify.sh` मौजूद न हो तब तक कुछ नहीं चलता। अगर आप ऐसी repository खोलते हैं जिसमें कोई नहीं है, तो plugin session की शुरुआत में ही यह बता देता है, बजाय चुप रहकर आपको यह मान लेने देने के कि आप कवर हैं।

## Plugin के बिना

hooks सादा bash हैं और उन्हें केवल `bash`, `git`, और `python3` चाहिए:

```bash
git clone https://github.com/Why-Next/prove-it ~/.local/share/prove-it
~/.local/share/prove-it/bin/prove-it init
```

[`hooks/settings.example.json`](../../hooks/settings.example.json) को एक repository के लिए अपने `.claude/settings.json` में, या उन सबके लिए `~/.claude/settings.json` में merge करें। gate stdin पर एक Stop hook JSON payload पढ़ता है और एक exit code से जवाब देता है, इसलिए कोई भी चीज़ जो turn के अंत में script चला सके, उसे चला सकती है। Claude Code वह जगह है जहाँ इसे test किया जाता है; [docs/ADAPTERS.md](../ADAPTERS.md) में Codex CLI, Qwen Code, Gemini CLI, और Copilot CLI के लिए wiring है, जो इसी तरह का blocking end-of-turn hook उपलब्ध कराते हैं, और वह साफ-साफ बताता है कि कौन-से hosts किसी gate को बिल्कुल भी नहीं चला सकते।

`prove-it doctor` यह जवाब देता है कि जिस repository में आप खड़े हैं उसमें gate चलेगा या नहीं, और अगर नहीं चलेगा तो बताता है कि उसे क्या रोक रहा है:

```
repository   /home/you/src/api
verify.sh    present and executable
working tree dirty
blocks       up to 3 per turn, then it yields with a warning
state        /home/you/.local/state/prove-it
ledger       off (export PROVE_IT_LEDGER=1 to record what the gate catches)
```

## gate को बढ़ाना

आप जो हर check जोड़ते हैं, वह इस सवाल के आपके जवाब का एक वाक्य है कि इस repository में "proven" का क्या मतलब है। वह test command जोड़ें जो आप सचमुच चलाते हैं, फिर type checker, फिर जो कुछ भी आपकी reviews बार-बार पकड़ती रहती हैं। जब पूरी script में लगभग एक मिनट लगने लगे तब रुक जाएँ; धीमे checks CI में होने चाहिए।

किसी check को चालू करने से पहले उसे अपने हाथ से चलाएँ। ऐसा कोई check भी कभी न भेजें जिसे आपने fail होते हुए न देखा हो: जो check fail ही नहीं हो सकता वह कोई check नहीं है, और जिस दिन आपको उसकी ज़रूरत होगी उस दिन आपको यह पता नहीं चलेगा।

आम गलती है पहले ही दिन एक महत्वाकांक्षी `verify.sh` लिख डालना। जो gate धीमा या अविश्वसनीय होता है, उसे एक हफ्ते के भीतर bypass कर दिया जाता है, और bypass किया गया gate किसी gate न होने से भी बुरा है, क्योंकि यह बताता है कि कोई check चला जबकि कुछ भी नहीं चला।

## यह चलने का फैसला कैसे करता है

gate तब तक चुप रहता है जब तक ये सब सच न हों:

- इस session ने इस repository को बदला
- repository की root पर एक executable `verify.sh` मौजूद है
- यह ठीक यही tree state पहले से pass नहीं हुई है

"बदला" का जवाब repository देती है, न कि इसका कोई लॉग कि कौन-से tools चले। session की शुरुआत में hook दर्ज कर लेता है कि tree कैसी दिखती थी, और हर stop पर वह पूछता है कि tree अब भी वैसी ही दिखती है या नहीं। `sed` से दोबारा लिखी गई कोई file, `git apply` से लगाया गया कोई patch, किसी code generator से निकली कोई file, और एक commit - ये सब बदलाव हैं, क्योंकि इन सभी से tree बदलती है। जिस session ने केवल पढ़ा वह कुछ भी नहीं गिना जाता, उस repository में भी जो खुलते समय पहले से गंदी थी।

आखिरी शर्त का मतलब है कि pass होने वाली tree हर stop पर नहीं, बल्कि एक ही बार verify होती है। जब verification fail होता है, तो agent को output की आखिरी बीस लाइनें दिखती हैं, जो आमतौर पर उसके लिए कारण ठीक करने के वास्ते काफी होती हैं, बिना यह बताए कि क्या गलत हुआ।

`PROVE_IT_SKIP=1` जान-बूझकर gate को पार कर जाता है। sessions के बीच `verify.sh` को delete करने से यह हमेशा के लिए बंद हो जाता है। दोनों escape hatch जान-बूझकर रखे गए हैं: लोग ऐसे gate के इर्द-गिर्द रास्ता निकाल लेते हैं जिसे वे हटा नहीं सकते। `PROVE_IT_MAX_BLOCKS` यह तय करता है कि एक turn को कितनी बार वापस भेजा जा सकता है, और `0` gate को कभी block किए बिना रिपोर्ट कराता है।

## जब agent gate को बदल देता है

सबसे कठिन failure mode कोई अविश्वसनीय check नहीं है। यह एक ऐसा agent है जो `verify.sh` को pass नहीं करा पाता और इसके बजाय `verify.sh` को ही बदल देता है।

इसका सबसे सस्ता रूप gate को सीधे निहत्था कर देना है, इसलिए gate इसे अस्वीकार कर देता है। hook दर्ज कर लेता है कि session शुरू होते समय `verify.sh` executable था या नहीं, और जो session उसे delete किए हुए या उसका executable bit हटाए हुए समाप्त होती है उसे block किया जाता है, बताया जाता है कि उसने क्या किया, और बताया जाता है कि अगर उसका यही इरादा था तो ईमानदारी से बाहर कैसे निकला जाए। sessions के बीच `verify.sh` को delete करना अब भी एक opt-out है और अब भी एक ही command लेता है।

सूक्ष्म रूप वह agent है जो `verify.sh` को executable बनाए रखता है और उसके भीतर के checks को दोबारा लिख देता है। उस pass को block नहीं किया जाता, क्योंकि `verify.sh` को edit करना अक्सर ठीक वही काम होता है जो आपने माँगा था, लेकिन अब यह चुपचाप भी नहीं रहता: जब कोई turn ऐसे `verify.sh` से होकर pass होती है जो session के दौरान बदला, तो gate आपको यह बता देता है, और `verify.sh` का diff आपको बताता है कि बदलाव काम था या बचने की चाल। वह diff पढ़ें। spec में diff साक्ष्य इसी के लिए है।

## `verify.sh` कन्वेंशन

`hooks/` में मौजूद script जान-बूझकर छोटी है। यह जो लागू करती है वह [SPEC.md](../../SPEC.md) में लिखा है: एक repository घोषित करती है कि वह खुद को कैसे साबित करती है, एक ज्ञात path पर, एक ज्ञात contract के साथ, और कोई agent तब तक completion का दावा नहीं कर सकता जब तक वह proof pass न हो जाए। spec एक file और एक exit code का नाम लेती है और कभी किसी vendor का नाम नहीं लेती, इसलिए plugin इस विचार को बाँटने का एक तरीका भर है, न कि खुद वह विचार।

एक `verify.sh` को जिन चार तरह के साक्ष्यों के विरुद्ध जोर देना चाहिए - command output, diff, reproduction, और cross-check - और conformance levels के लिए spec पढ़ें।

## यह क्या नहीं करता

gate एक ही चीज़ लागू करता है: कि turn समाप्त होने से पहले `verify.sh` ने zero लौटाया। उस zero का कोई मतलब है या नहीं, यह पूरी तरह उन checks पर निर्भर करता है जो आपने लिखे। केवल `exit 0` वाला `verify.sh` इस gate को pass कर जाता है और कुछ भी साबित नहीं करता।

spec इसे Level 1 कहती है। Level 2 यह है कि आपके checks असली साक्ष्य के विरुद्ध जोर देते हैं या नहीं, और कोई tool इसे आपके लिए verify नहीं कर सकता, यह वाला भी शामिल।

तीन और सीमाएँ, साफ-साफ बताई गई हैं क्योंकि वरना आप इन्हें किसी बुरे मौके पर पाएँगे। gate `PROVE_IT_MAX_BLOCKS` अस्वीकारों के बाद हार मान लेता है, इसलिए एक अड़ा हुआ agent अपनी turn के अंत तक पहुँच ही जाता है; जो वह नहीं कर सकता वह है वहाँ चुपचाप पहुँचना। जिन files को आपका `.gitignore` बाहर रखता है वे बदलाव का पता लगाने के लिए अदृश्य होती हैं, इसलिए ऐसा `verify.sh` जो किसी ignored `.env` को पढ़ता है, जब केवल वही file बदली हो तो skip हो सकता है। और जो session उस repository के बाहर शुरू होती है जिसे वह बाद में संपादित करती है, उसके पास तुलना करने के लिए कोई baseline नहीं होती, जो gate को इस कमज़ोर test पर वापस गिरा देता है कि working tree गंदी है या नहीं।

## रेसिपी

हर stack के लिए शुरुआती बिंदु [`recipes/`](../../recipes/) में हैं। किसी एक को `verify.sh` में copy करें और जो लागू नहीं होता उसे काट दें। इसे एक मिनट के भीतर रखें; धीमे checks CI में होने चाहिए।

| | |
|---|---|
| [`node.sh`](../../recipes/node.sh) | tests, typecheck, lint, diff की साफ-सफाई |
| [`python.sh`](../../recipes/python.sh) | pytest, ruff, mypy |
| [`go.sh`](../../recipes/go.sh) | go test, vet, gofmt check |
| [`flutter.sh`](../../recipes/flutter.sh) | analyze, test, format check |

hook जोड़ना आसान हिस्सा है। असली काम यह जवाब देना है कि आपकी repository में "proven" का क्या मतलब है, और कोई recipe आपके लिए वह जवाब नहीं देती।

## लेजर

`PROVE_IT_LEDGER=1` सेट करें और हर पकड़ी गई झूठी completion `~/.prove-it/ledger.jsonl` में एक line जोड़ देती है:

```json
{"ts":"2026-07-09T04:12:33Z","claim":"All tests pass. Ready to merge.",
 "evidence_demanded":"verify.sh exit 0","actual":["3 failed, 41 passed"]}
```

यह line दर्ज करती है कि agent ने क्या दावा किया, उससे क्या माँगा गया, और असल में क्या सच निकला। file स्थानीय disk पर mode `0600` के साथ लिखी जाती है, कोई इसे कहीं भी transmit नहीं करता, और जब तक आप इसे चालू न करें यह बंद रहती है। एक महीने की entries के बाद आप यह अंदाज़ा लगाना बंद कर सकते हैं कि आपका agent कैसे fail होता है और इसके बजाय उसे पढ़ सकते हैं। `/prove-it:ledger` आपके लिए file का सारांश दे देता है, और command line पर `prove-it ledger` भी वही करता है।

## यह repo खुद को gate करता है

`prove-it` के पास एक `verify.sh` है, और यह जो चलाता है उसका एक हिस्सा खुद gate है, जो एक temporary directory में असली git repositories के विरुद्ध चलता है: एक failing check block करता है, एक passing check अनुमति देता है, एक read-only session को छोड़ दिया जाता है, commit के बाद साफ tree को no work नहीं माना जाता, bypass काम करता है।

```bash
./verify.sh
```

CI उसी script को Linux और macOS पर चलाता है, साथ ही एक अलग job जो साबित करता है कि gate अब भी उस repository को block करता है जिसके checks fail होते हैं। Repository CodeQL, OpenSSF Scorecard, और tag release workflow भी चलाती है, जो source को checksum और GitHub provenance attestation के साथ package करता है।

## Project trust

जिन repositories पर आपको भरोसा नहीं है उनमें इसे इस्तेमाल करने से पहले [SECURITY.md](../../SECURITY.md) पढ़ें। `prove-it` repository-owned `verify.sh` चलाता है; यह guardrail है, sandbox नहीं।

Release steps [RELEASE.md](../../RELEASE.md) में हैं, जिनमें verification, workflow status, checksums, और provenance attestation की checklist शामिल है। Support boundaries [SUPPORT.md](../../SUPPORT.md) में हैं।

## योगदान

Issues और pull requests का स्वागत है। convention में बदलाव reference implementation के विरुद्ध pull request के बजाय किसी issue में होने चाहिए। देखें [CONTRIBUTING.md](../../CONTRIBUTING.md)।

## लाइसेंस

MIT.
