import 'bystander_lang.dart';

/// One instruction, in the three pilot languages.
class FirstAidStep {
  const FirstAidStep({required this.text, required this.isProhibition});

  final L3 text;

  /// Prohibitions ("do not ...") are rendered first and marked, because the
  /// most common bystander harm at an Indian crash scene is well-meant
  /// movement of the casualty, not inaction.
  final bool isProhibition;
}

/// FR-093 content.
///
/// DELIBERATELY MINIMAL. Everything here is either a prohibition or an action
/// an untrained person cannot make worse. No airway manoeuvres, no CPR
/// instruction, no spinal handling, no tourniquet technique -- those need
/// training this reader does not have, and a screen cannot supply it.
///
/// This block ships as DRAFT. It must be signed off by a qualified emergency
/// physician before launch; [reviewStatus] is rendered on screen until then.
abstract final class FirstAidGuidance {
  static const reviewStatus = 'DRAFT -- pending medical review before launch';

  static const steps = <FirstAidStep>[
    FirstAidStep(
      isProhibition: true,
      text: L3(
        'Do not move them, and do not remove a helmet.',
        'അവരെ ഇളക്കരുത്, ഹെൽമറ്റ് ഊരരുത്.',
        'उन्हें हिलाएँ नहीं, हेलमेट न उतारें।',
      ),
    ),
    FirstAidStep(
      isProhibition: true,
      text: L3(
        'Do not give water, food or medicine.',
        'വെള്ളമോ ഭക്ഷണമോ മരുന്നോ കൊടുക്കരുത്.',
        'पानी, खाना या दवा न दें।',
      ),
    ),
    FirstAidStep(
      isProhibition: false,
      text: L3(
        'Check whether they are breathing. Tell the 112 operator the answer.',
        'ശ്വാസം എടുക്കുന്നുണ്ടോ എന്ന് നോക്കുക. 112 ഓപ്പറേറ്ററോട് പറയുക.',
        'देखें कि साँस चल रही है या नहीं। 112 ऑपरेटर को बताएँ।',
      ),
    ),
    FirstAidStep(
      isProhibition: false,
      text: L3(
        'If bleeding heavily, press firmly on the wound with a clean cloth.',
        'ധാരാളം രക്തസ്രാവമുണ്ടെങ്കിൽ വൃത്തിയുള്ള തുണികൊണ്ട് അമർത്തിപ്പിടിക്കുക.',
        'ज़्यादा खून बह रहा हो तो साफ़ कपड़े से घाव पर दबाव डालें।',
      ),
    ),
    FirstAidStep(
      isProhibition: false,
      text: L3(
        'Keep them warm and keep traffic away until help arrives.',
        'അവരെ ചൂടോടെ സൂക്ഷിക്കുക, സഹായം എത്തുംവരെ വാഹനങ്ങളിൽ നിന്ന് അകറ്റുക.',
        'उन्हें गर्म रखें और मदद आने तक ट्रैफ़िक से दूर रखें।',
      ),
    ),
  ];
}
