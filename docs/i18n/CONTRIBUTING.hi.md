# योगदान

## बदलाव कहाँ होना चाहिए

इस repository में दो चीज़ें हैं जिनका वज़न अलग-अलग है।

[SPEC.md](../../SPEC.md) एक ऐसे convention का वर्णन करती है जिसे दूसरे tools इस code की एक भी line पढ़े बिना लागू कर सकें। इसमें बदलाव किसी issue के रूप में शुरू होते हैं, ताकि किसी के patch लिखने से पहले चर्चा हो जाए। ऐसा pull request जो चुपचाप contract को चौड़ा कर देता है, उससे बहस करना उस प्रस्ताव की तुलना में कठिन है जो साफ-साफ कहता है कि वह क्या बदलना चाहता है।

`hooks/prove-it.sh` उस convention का एक implementation है, कोई सत्तर-कुछ लाइनों का, और उसके विरुद्ध pull requests को किसी औपचारिकता की ज़रूरत नहीं।

अगर आप अनिश्चित हैं कि आप दोनों में से किसे छू रहे हैं, तो एक issue खोलें और पूछें।

## gate आप पर भी लागू होता है

इस repository के पास एक `verify.sh` है। कोई pull request खोलने से पहले इसे चलाएँ:

```bash
./verify.sh
```

यह shell syntax जाँचता है, shellcheck चलाता है, plugin manifests को validate करता है, नीचे दिए गद्य नियमों को लागू करता है, अनुवादों को उनके अंग्रेजी मूल के अनुरूप रखता है, और एक temporary directory में असली git repositories के विरुद्ध gate का अपना test suite चलाता है। CI उसी script को Linux और macOS पर चलाता है, साथ ही एक अलग job जो साबित करता है कि gate अब भी उस repository को block करता है जिसके checks fail होते हैं।

अगर `verify.sh` fail होता है, तो कारण ठीक करें। `verify.sh` को कमज़ोर न करें। यही एक बदलाव है जिसे यह project merge नहीं करेगा, ठीक उसी वजह से जिसके लिए यह project मौजूद है।

## कोई check जोड़ना

कोई नया check तब स्वागत योग्य है जब उसने किसी असली bug को पकड़ा होता। जान-बूझकर कुछ तोड़ें, अपने check को उसे भाँपते हुए देखें, फिर उसे ठीक करें और दोनों को commit करें। ऐसा check जिसे किसी ने fail होते न देखा हो, वह check नहीं है।

`scripts/` के अंतर्गत दो scripts इसलिए मौजूद हैं क्योंकि उनके पहले संस्करण एक ऐसे codebase के विरुद्ध pass हो गए थे जो पहले से ही टूटा हुआ था।

## अनुवाद

`README.md` और `SPEC.md` प्रामाणिक हैं, और जहाँ कोई अनुवाद असहमत हो वहाँ `SPEC.md` का अंग्रेजी पाठ शासन करता है। `scripts/check_i18n.py` हर अनुवाद को उसके मूल के अनुरूप रखता है: heading की गिनती, headings का अनुवाद हुआ भी या नहीं, accents बचे या नहीं, code blocks अंग्रेजी से byte-identical हैं या नहीं, और relative links सुलझते हैं या नहीं।

दो नियम लोगों को उलझा देते हैं।

कभी लंबा dash इस्तेमाल न करें। कोई em dash, en dash, horizontal bar, या minus sign नहीं। हर भाषा में केवल सादा ASCII hyphen, उन भाषाओं में भी जिनकी typography कुछ और पसंद करती है, क्योंकि लंबा dash मशीन के लिखे पाठ जैसा पढ़ा जाता है। (यह अनुच्छेद उन characters को दिखाने के बजाय उनके नाम लेता है, क्योंकि `scripts/check_no_long_dash.py` इस file को भी पढ़ता है।)

accents हमेशा बनाए रखें। dash नियम छह विशिष्ट characters को कवर करता है और non-ASCII पर कोई प्रतिबंध नहीं है। `décidé` वैसे का वैसा `décidé` रहता है, और `è` कभी `e'` नहीं बनता। एक शुरुआती अनुवाद ने पहले नियम को हद से ज़्यादा लागू करके file के हर accent को हटा दिया था।

## रेसिपी

एक recipe किसी तैयार `verify.sh` के बजाय एक stack के लिए शुरुआती बिंदु है। इसे एक मिनट के runtime के भीतर रखें, राय पैदा करने वाले checks के बजाय साक्ष्य पैदा करने वाले checks को प्राथमिकता दें, और यह नोट करें कि हर check spec के चार तरह के साक्ष्यों में से कौन-सा देता है।

## कमिट

Conventional commits (`feat:`, `fix:`, `docs:`, `chore:`)। body में बताएँ कि क्या बदला और क्यों। अगर आपने कोई bug ठीक किया, तो बताएँ कि आपने उसे कैसे reproduce किया।

## Releases

Maintainers [RELEASE.md](../../RELEASE.md) का पालन करते हैं। Release के लिए clean local `./verify.sh`, `main` पर green `verify`, `codeql`, और `scorecard` workflows, और tag workflow का checksum plus provenance attestation चाहिए। Unverified tree से publish न करें।
