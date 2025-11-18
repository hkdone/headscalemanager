import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

class IpUtils {
  /// Validates if a given string is a valid IPv4 or IPv6 address.
  static bool isValidIp(String ip) {
    try {
      InternetAddress(ip);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Checks if a given IP address is within a specific subnet in CIDR notation.
  static bool isIpInSubnet(String ip, String subnet) {
    try {
      final ipAddress = InternetAddress(ip);
      final subnetParts = subnet.split('/');
      if (subnetParts.length != 2) return false;

      final subnetAddress = InternetAddress(subnetParts[0]);
      final prefixLength = int.tryParse(subnetParts[1]);
      if (prefixLength == null) return false;

      if (ipAddress.type != subnetAddress.type) return false;

      final ipBytes = ipAddress.rawAddress;
      final subnetBytes = subnetAddress.rawAddress;

      int bits = 0;
      for (int i = 0; i < (prefixLength / 8).ceil(); i++) {
        if (i * 8 >= prefixLength) break;
        int bitsToCompare = min(8, prefixLength - i * 8);
        int mask = (0xFF << (8 - bitsToCompare)) & 0xFF;
        if ((ipBytes[i] & mask) != (subnetBytes[i] & mask)) {
          return false;
        }
        bits += bitsToCompare;
      }
      return bits >= prefixLength;
    } catch (_) {
      return false;
    }
  }

  /// Generates a list of IP addresses from a start IP to an end IP (inclusive).
  static List<String> generateIpRange(String startIp, String endIp) {
    try {
      final start = InternetAddress(startIp);
      final end = InternetAddress(endIp);

      if (start.type != end.type) {
        throw ArgumentError('Start and end IP addresses must be of the same type.');
      }

      final startBytes = start.rawAddress;
      final endBytes = end.rawAddress;
      final result = <String>[];

      BigInt startNum = _bytesToBigInt(startBytes);
      final BigInt endNum = _bytesToBigInt(endBytes);

      if (startNum > endNum) {
        throw ArgumentError('Start IP must be less than or equal to End IP.');
      }

      while (startNum <= endNum) {
        result.add(InternetAddress.fromRawAddress(
                Uint8List.fromList(_bigIntToBytes(startNum, startBytes.length)))
            .address);
        startNum += BigInt.one;
      }
      return result;
    } catch (e) {
      // Return an empty list or rethrow as a more specific exception
      return [];
    }
  }

  static BigInt _bytesToBigInt(List<int> bytes) {
    BigInt result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  static List<int> _bigIntToBytes(BigInt number, int byteLength) {
    final result = List<int>.filled(byteLength, 0);
    for (int i = byteLength - 1; i >= 0; i--) {
      result[i] = (number & BigInt.from(0xff)).toInt();
      number = number >> 8;
    }
    return result;
  }

  /// Validates if a given string is in CIDR notation.
  static bool isCIDR(String input) {
    return input.contains('/');
  }
}
