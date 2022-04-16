import 'dart:math';
import 'crypto.dart';
import 'language.dart';

/// BIP39: A mnemonic sentence is superior for human interaction compared to the handling of raw binary or hexadecimal representations of a wallet seed.
class Mnemonic {
  /// BIP39: The mnemonic must encode entropy in a multiple of 32 bits.
  /// With more entropy security is improved but the sentence length increases.
  /// The allowed size of _ENT is 128-256 bits.
  late List<int> entropy;

  /// BIP39: We refer to the initial entropy length as ENT.
  // ignore: non_constant_identifier_names
  int get _ENT => entropy.length * 8;

  /// BIP39: The checksum length (CS)
  // ignore: non_constant_identifier_names
  int get _CS => _ENT ~/ 32;

  /// BIP39: The length of the generated mnemonic sentence (MS) in words.
  // ignore: non_constant_identifier_names
  int get _MS => (_ENT + _CS) ~/ 11;

  /// Constructs Mnemonic from entropy bytes.
  Mnemonic(this.entropy) {
    if (![128, 160, 192, 224, 256].contains(_ENT)) {
      throw Exception("mnemonic: unexpected initial entropy length");
    }
  }

  /// Constructs Mnemonic from random secure 256 bits entropy.
  Mnemonic.generate() {
    var random = Random.secure();
    entropy = List<int>.generate(32, (i) => random.nextInt(256));
  }

  /// Constructs Mnemonic from a sentence by retrieving the original entropy.
  Mnemonic.fromSentence(String sentence, Language language) {
    List<String> words = sentence.split(' ');
    List<int> indexes = [];
    Map<int, String> map = language.map;
    // convert to indexes.
    for (var word in words) {
      if (map.containsValue(word) == false) {
        throw Exception('mnemonic: "$word" does not exist in $language');
      } else {
        int index = map.entries.firstWhere((entry) => entry.value == word).key;
        indexes.add(index);
      }
    }
    // determine checksum length in bits.
    int checksumLength;
    switch (indexes.length) {
      case 12:
        checksumLength = 4;
        break;
      case 15:
        checksumLength = 5;
        break;
      case 18:
        checksumLength = 6;
        break;
      case 21:
        checksumLength = 7;
        break;
      case 24:
        checksumLength = 8;
        break;
      default:
        throw Exception("mnemonic: unexpected sentence length");
    }
    // convert indexes to bits to remove the checksum.
    String bits = indexes
        .map((byte) => byte
            .toRadixString(2)
            .padLeft(11, '0')) // (each index is encoded on 11 bits)
        .join('');
    // remove checksum from bits.
    var bitsEntropy = bits.substring(0, bits.length - checksumLength);
    // converts bits entropy back to bytes.
    entropy = [];
    for (var i = 0; i < bitsEntropy.length; i += 8) {
      String bit = bitsEntropy.substring(i, i + 8);
      entropy.add(int.parse(bit, radix: 2));
    }
  }

  /// BIP39: A checksum is generated by taking the first _ENT / 32 bits of its SHA256 hash.
  List<int> get checksum => sha256(entropy).sublist(0, _CS ~/ 8);

  /// Returns entropy + checksum in binary string.
  /// * BIP39: This checksum is appended to the end of the initial entropy.
  String get binary {
    List<int> bytes = entropy + checksum;
    return bytes.map((byte) => byte.toRadixString(2).padLeft(8, '0')).join('');
  }

  /// Returns mnemonic indexes
  /// * BIP39: Next, these concatenated bits are split into groups of 11 bits, each encoding a number from 0-2047, serving as an index into a wordlist.
  List<int> get indexes {
    List<int> indexes = [];
    for (var i = 0; i < binary.length; i += 11) {
      String bit = binary.substring(i, i + 11);
      indexes.add(int.parse(bit, radix: 2));
    }
    indexes.length != _MS ? throw Exception("mnemonic: indexes length") : null;
    return indexes;
  }

  /// Returns mnemonic sentence encoded in the specified language.
  /// * BIP39: Finally, we convert these numbers into words and use the joined words as a mnemonic sentence.
  String toSentence(Language language) {
    List<String> result = [];
    for (int index in indexes) {
      result.add(language.list[index]);
    }
    return result.join(' ');
  }

  /// BIP39:
  /// * A user may decide to protect their mnemonic with a passphrase. If a passphrase is not present, an empty string "" is used instead.
  /// * To create a binary seed from the mnemonic, we use the PBKDF2 function with a mnemonic sentence (in UTF-8 NFKD) used as the password and the string "mnemonic" + passphrase (again in UTF-8 NFKD) used as the salt.
  /// The iteration count is set to 2048 and HMAC-SHA512 is used as the pseudo-random function.
  /// The length of the derived key is 512 bits (= 64 bytes).
  /// * This seed can be later used to generate deterministic wallets using BIP-0032 or similar methods.
  List<int> toSeed({String passphrase = ""}) {
    return pbkdf2(entropy, passphrase: passphrase);
  }
}