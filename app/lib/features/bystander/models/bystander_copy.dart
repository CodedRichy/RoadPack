import 'bystander_lang.dart';

/// Every string on the bystander screen, in the three pilot languages.
///
/// Wording rules this block is held to:
/// * It never claims RoadPack contacts, dispatches, or sends anything to 112.
///   There is no public ERSS API. The app shortens the awareness gap; the
///   human standing there still has to make the call (FR-110, C8).
/// * It never presents unverified hospital data as verified (FR-111/114).
/// * The medical block is deliberately below what an untrained person could
///   get wrong, and is marked as awaiting review (FR-093, C10).
abstract final class BystanderCopy {
  static const title = L3(
    'This person may need help',
    'ഈ വ്യക്തിക്ക് സഹായം വേണ്ടിവരാം',
    'इस व्यक्ति को मदद की ज़रूरत हो सकती है',
  );

  static const subtitle = L3(
    'Their phone raised an emergency. You do not need to unlock it.',
    'ഈ ഫോൺ ഒരു അടിയന്തരാവസ്ഥ അറിയിച്ചു. ഫോൺ അൺലോക്ക് ചെയ്യേണ്ടതില്ല.',
    'इस फ़ोन ने आपातकाल की सूचना दी है। फ़ोन अनलॉक करने की ज़रूरत नहीं है।',
  );

  static const dial112 = L3('Call 112', '112 വിളിക്കുക', '112 पर कॉल करें');

  static const dial112Sub = L3(
    'Police, ambulance and fire',
    'പോലീസ്, ആംബുലൻസ്, ഫയർ',
    'पुलिस, एम्बुलेंस और फ़ायर',
  );

  static const dialContact = L3(
    'Call their emergency contact',
    'ഇവരുടെ അടിയന്തര ബന്ധുവിനെ വിളിക്കുക',
    'इनके आपातकालीन संपर्क को कॉल करें',
  );

  static const directions = L3(
    'Directions to nearest hospital',
    'അടുത്തുള്ള ആശുപത്രിയിലേക്കുള്ള വഴി',
    'नज़दीकी अस्पताल का रास्ता',
  );

  static const noContact = L3(
    'No emergency contact saved on this phone',
    'ഈ ഫോണിൽ അടിയന്തര ബന്ധുവിന്റെ വിവരം ഇല്ല',
    'इस फ़ोन में कोई आपातकालीन संपर्क सेव नहीं है',
  );

  static const noHospital = L3(
    'No cached hospital nearby. Ask the 112 operator.',
    'അടുത്ത് ആശുപത്രി വിവരം ലഭ്യമല്ല. 112 ഓപ്പറേറ്ററോട് ചോദിക്കുക.',
    'पास का अस्पताल उपलब्ध नहीं। 112 ऑपरेटर से पूछें।',
  );

  static const locationHeading = L3(
    'Location of this phone',
    'ഈ ഫോണിന്റെ സ്ഥാനം',
    'इस फ़ोन की जगह',
  );

  /// The honesty clause. There is no automatic data push to 112.
  static const readAloud = L3(
    'Read this out to the 112 operator. RoadPack cannot send it for you.',
    '112 ഓപ്പറേറ്ററോട് ഇത് വായിച്ചു പറയുക. RoadPack ഇത് സ്വയം അയയ്ക്കില്ല.',
    'यह 112 ऑपरेटर को पढ़कर बताएँ। RoadPack इसे खुद नहीं भेज सकता।',
  );

  static const noFix = L3(
    'This phone has no location fix. Describe the place instead.',
    'ഈ ഫോണിന് സ്ഥാനം ലഭ്യമല്ല. സ്ഥലം വിവരിച്ചു പറയുക.',
    'इस फ़ोन को लोकेशन नहीं मिली। जगह का विवरण बताएँ।',
  );

  static const samaritanHeading = L3(
    'You are legally protected for helping',
    'സഹായിക്കുന്ന നിങ്ങൾക്ക് നിയമപരമായ സംരക്ഷണം ഉണ്ട്',
    'मदद करने पर आप कानूनी रूप से सुरक्षित हैं',
  );

  static const samaritanBody = L3(
    'Section 134A, Motor Vehicles Act: a bystander who helps an injured '
        'person cannot be detained, questioned about their identity, or made '
        'to pay for treatment.',
    'മോട്ടോർ വാഹന നിയമം സെക്ഷൻ 134A: പരിക്കേറ്റ ആളെ സഹായിക്കുന്ന ആളെ '
        'തടഞ്ഞുവയ്ക്കാനോ വ്യക്തിവിവരങ്ങൾ ചോദിക്കാനോ ചികിത്സാച്ചെലവ് '
        'ഈടാക്കാനോ പാടില്ല.',
    'मोटर वाहन अधिनियम की धारा 134A: घायल की मदद करने वाले को रोका नहीं जा '
        'सकता, उसकी पहचान नहीं पूछी जा सकती, और इलाज का ख़र्च नहीं लिया जा '
        'सकता।',
  );

  static const firstAidHeading = L3(
    'While you wait for help',
    'സഹായം എത്തുന്നതുവരെ',
    'मदद आने तक',
  );

  static const notMedicalAdvice = L3(
    'Basic steps only, not medical advice. Draft content: pending medical '
        'review before launch.',
    'അടിസ്ഥാന നിർദ്ദേശങ്ങൾ മാത്രം, വൈദ്യോപദേശമല്ല. കരട് ഉള്ളടക്കം: '
        'വൈദ്യപരിശോധന (medical review) ബാക്കി.',
    'सिर्फ़ बुनियादी क़दम, चिकित्सकीय सलाह नहीं। मसौदा सामग्री: लॉन्च से '
        'पहले medical review बाक़ी।',
  );

  static const iceHeading = L3(
    'Medical details for the paramedic',
    'പാരാമെഡിക്കിനുള്ള മെഡിക്കൽ വിവരങ്ങൾ',
    'पैरामेडिक के लिए मेडिकल जानकारी',
  );

  static const iceGateNote = L3(
    'Shown only while this emergency is active.',
    'ഈ അടിയന്തരാവസ്ഥ സജീവമായിരിക്കുമ്പോൾ മാത്രം കാണിക്കുന്നു.',
    'यह जानकारी सिर्फ़ आपातकाल के दौरान दिखती है।',
  );

  static const unverified = L3(
    'Unverified data -- confirm before relying on it',
    'പരിശോധിക്കാത്ത വിവരം -- ആശ്രയിക്കും മുൻപ് ഉറപ്പാക്കുക',
    'असत्यापित जानकारी -- भरोसा करने से पहले पुष्टि करें',
  );

  static const straightLine = L3(
    'straight line, not road distance',
    'നേർരേഖ ദൂരം, റോഡ് ദൂരമല്ല',
    'सीधी दूरी, सड़क दूरी नहीं',
  );
}
