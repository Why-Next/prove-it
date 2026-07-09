# सुरक्षा

## यह software आपकी मशीन पर क्या करता है

`prove-it` एक ऐसी script चलाता है जो आपके खोले हुए repository में रहती है। अगर आप कोई ऐसा repository खोलते हैं जिस पर आप भरोसा नहीं करते, और उसका `verify.sh` executable है, तो आपके agent द्वारा किसी turn को समाप्त करने पर वह file चल जाएगी।

यह व्यवहार इसमें कोई दोष नहीं बल्कि design है, और जोखिम वही है जिसे आप `npm install` चलाते समय या किसी `Makefile` वाले project को खोलते समय पहले से स्वीकार करते हैं। किसी अनजान `verify.sh` को उस repository में agent से काम कराने से पहले पढ़ें जिसमें वह मौजूद है, ठीक वैसे ही जैसे आप किसी अनजान `postinstall` script को पढ़ेंगे।

gate केवल तभी चलता है जब session ने **उसी repository को** बदला हो और उसकी root पर एक executable `verify.sh` मौजूद हो। किसी repository को clone और पढ़ना इसे कभी trigger नहीं करता, और एक repository को बदलना कभी किसी दूसरी repository के `verify.sh` को नहीं चलाता।

`prove-it doctor` इसका अपवाद है, और यह जान-बूझकर है: आपने इससे gate चलाने को कहा, इसलिए यह `verify.sh` को तुरंत चला देता है, चाहे आप किसी भी repository में खड़े हों। जिस repository के `verify.sh` को आपने पढ़ा नहीं है, उसके भीतर इसे न चलाएँ।

इसमें से कुछ भी sandbox नहीं है। hooks और उनका हिसाब-किताब आपके रूप में चलते हैं, और agent का shell भी, इसलिए जो agent gate को हराने पर उतर आया हो, वह state directory को मिटा सकता है और फिर `verify.sh` को निरस्त्र कर सकता है। `prove-it` उस agent के विरुद्ध एक guardrail है जो आत्मविश्वास के साथ गलत है, और आपके पास यही वाला है। यह किसी विरोधी agent के विरुद्ध एक सीमा नहीं है। जिस जाँच तक कोई शत्रुतापूर्ण agent पहुँच न सके, उसे कहीं ऐसी जगह चलना होगा जहाँ वह पहुँच न सके, और वह जगह CI है।

## यह disk पर क्या लिखता है

छोटी bookkeeping files, सभी mode `0700` में बनी एक निजी directory में:
`$XDG_STATE_HOME/prove-it/`, या जब वह अनसेट हो तो `~/.local/state/prove-it/`।
`PROVE_IT_STATE_DIR` से इसे override करें। ये दर्ज करती हैं कि session शुरू होते समय tree कैसी दिखती थी, उस क्षण gate armed था या नहीं, किसी session ने किन repositories में लिखा है, कौन-सी tree states पहले से pass हो चुकी हैं, और मौजूदा turn को कितनी बार वापस भेजा गया है। हर एक में एक checksum या एक छोटा integer होता है, कभी file की सामग्री नहीं। साझा `/tmp` में कुछ नहीं लिखा जाता, क्योंकि ये filenames repository path से बनते हैं और इसलिए predictable होते हैं, और किसी world-writable directory में एक predictable नाम एक symlink target होता है।

session पहचानकर्ता hook के JSON payload में आता है और उन्हीं filenames में से एक के भीतर पहुँच जाता है, इसलिए उपयोग से पहले इसे घटाकर अक्षरों, अंकों, dash, और underscore तक सीमित कर दिया जाता है। कोई payload path के हिस्सों का भरोसेमंद स्रोत नहीं है।

वैकल्पिक ledger (`PROVE_IT_LEDGER=1`, **डिफ़ॉल्ट रूप से बंद**) हर पकड़ी गई झूठी completion के लिए `~/.prove-it/ledger.jsonl` में एक JSON line जोड़ता है, जो एक `0700` directory के भीतर mode `0600` में बनी होती है। हर line में यह होता है:

- agent का वह आखिरी संदेश जो उसके रुकने की कोशिश करने से पहले का है, 300 characters
  तक काटा हुआ और आपके स्थानीय transcript से लिया गया, इसलिए इसमें आपकी बातचीत की
  कोई भी चीज़ हो सकती है
- repository का absolute path
- exit code, और आपके `verify.sh` output की वे लाइनें जो किसी विफलता का नाम लेती हैं
- एक timestamp

इसे बातचीत के डेटा की तरह मानें। इस project में कुछ भी इसे वापस नहीं पढ़ता या कहीं नहीं भेजता, पर यह एक साधारण file बनी रहती है, इसलिए आपके backups इसे copy कर लेंगे और आपके home directory तक पढ़ने की पहुँच रखने वाला कोई भी इसे खोल सकता है।

## यह क्या भेजता है

कुछ नहीं। जो software आपकी मशीन पर चलता है उसमें कोई telemetry नहीं, कोई network call नहीं, और कोई update check नहीं। आप इसकी पुष्टि `hooks/` और `scripts/` में `curl`, `wget`, `urllib`, `requests`, या `socket` के लिए एक ही grep से कर सकते हैं।

Continuous integration एकमात्र अपवाद है, और यह वह code नहीं है जिसे आप चलाते हैं: GitHub Actions workflow वही `verify.sh` चलाने से पहले `apt` या `brew` से `shellcheck` install करता है जिसे आप स्थानीय रूप से चलाते।

## किसी vulnerability की रिपोर्ट करना

विवरण और एक reproduction के साथ **hello@whynext.app** पर email करें। कृपया ऐसी किसी चीज़ के लिए public issue न खोलें जो किसी repository को ऊपर बताई गई सीमाओं से बाहर निकलने देती हो।

कुछ ही दिनों में एक स्वीकृति की उम्मीद रखें। इसे एक ही व्यक्ति maintain करता है, इसलिए धैर्य मदद करता है, और reproduction भी। जिस रिपोर्ट को मैं reproduce नहीं कर सकता, उसे मैं ठीक भी नहीं कर सकता।

## समर्थित संस्करण

नवीनतम release। यह project इतना छोटा है कि backporting कोई ऐसी सेवा नहीं है जिससे किसी को फायदा हो।
