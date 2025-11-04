import 'dart:convert';
import 'package:aws_common/aws_common.dart';
import 'package:aws_signature_v4/aws_signature_v4.dart';

/// AWS Admin Service - Manages Cognito admin operations using official AWS SDK
class AWSAdminService {
  // AWS Configuration
  static const String region = 'ap-south-1';
  static const String userPoolId = 'ap-south-1_LSTShtM9R';

  // AWS Credentials - CONFIGURED
  // ⚠️ SECURITY: Do not commit this file to public repositories!
  static const String accessKeyId = 'AKIAXJ5YBP2HHKNQ334T';
  static const String secretAccessKey =
      '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';

  // AWS Signer
  final AWSSigV4Signer _signer = AWSSigV4Signer(
    credentialsProvider: AWSCredentialsProvider(
      AWSCredentials(accessKeyId, secretAccessKey),
    ),
  );

  /// Create a new user in AWS Cognito
  Future<Map<String, dynamic>> createUser({
    required String email,
    required String tempPassword,
    required String role, // 'admin' or 'client'
    String? displayName,
    List<String>? assignedDevices,
  }) async {
    try {
      // Check if credentials are set
      if (accessKeyId == 'YOUR_AWS_ACCESS_KEY_ID' ||
          secretAccessKey == 'YOUR_AWS_SECRET_ACCESS_KEY') {
        return {
          'success': false,
          'message':
              'AWS credentials not configured. Please set your Access Key ID and Secret Access Key in aws_admin_service.dart',
          'needsSetup': true,
        };
      }

      // Build user attributes
      List<Map<String, String>> userAttributes = [
        {'Name': 'email', 'Value': email},
        {'Name': 'email_verified', 'Value': 'true'},
        {'Name': 'custom:role', 'Value': role},
      ];

      if (displayName != null && displayName.isNotEmpty) {
        userAttributes.add({'Name': 'name', 'Value': displayName});
      }

      if (assignedDevices != null && assignedDevices.isNotEmpty) {
        userAttributes.add({
          'Name': 'custom:assigned_devices',
          'Value': assignedDevices.join(',')
        });
      }

      // Build request body
      final Map<String, dynamic> requestBody = {
        'UserPoolId': userPoolId,
        'Username': email,
        'UserAttributes': userAttributes,
        'TemporaryPassword': tempPassword,
        'MessageAction': 'SUPPRESS',
      };

      // Make API call
      final response = await _makeAWSRequest(
        'AdminCreateUser',
        requestBody,
      );

      if (response['success'] == true) {
        // Set permanent password
        await setPermanentPassword(email, tempPassword);
        return {'success': true, 'message': 'User created successfully'};
      } else {
        return response;
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  /// Set permanent password for a user
  Future<Map<String, dynamic>> setPermanentPassword(
    String email,
    String password,
  ) async {
    try {
      final Map<String, dynamic> requestBody = {
        'UserPoolId': userPoolId,
        'Username': email,
        'Password': password,
        'Permanent': true,
      };

      return await _makeAWSRequest('AdminSetUserPassword', requestBody);
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  /// Delete a user from AWS Cognito
  Future<Map<String, dynamic>> deleteUser(String email) async {
    try {
      final Map<String, dynamic> requestBody = {
        'UserPoolId': userPoolId,
        'Username': email,
      };

      return await _makeAWSRequest('AdminDeleteUser', requestBody);
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  /// Update user attributes
  Future<Map<String, dynamic>> updateUser({
    required String email,
    String? displayName,
    String? role,
    List<String>? assignedDevices,
  }) async {
    try {
      List<Map<String, String>> userAttributes = [];

      if (displayName != null) {
        userAttributes.add({'Name': 'name', 'Value': displayName});
      }
      if (role != null) {
        userAttributes.add({'Name': 'custom:role', 'Value': role});
      }
      if (assignedDevices != null) {
        userAttributes.add({
          'Name': 'custom:assigned_devices',
          'Value': assignedDevices.join(',')
        });
      }

      final Map<String, dynamic> requestBody = {
        'UserPoolId': userPoolId,
        'Username': email,
        'UserAttributes': userAttributes,
      };

      return await _makeAWSRequest('AdminUpdateUserAttributes', requestBody);
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  /// List all users in the User Pool
  Future<Map<String, dynamic>> listUsers() async {
    try {
      final Map<String, dynamic> requestBody = {
        'UserPoolId': userPoolId,
      };

      return await _makeAWSRequest('ListUsers', requestBody);
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  /// Make an AWS API request using official AWS SigV4 Signer
  Future<Map<String, dynamic>> _makeAWSRequest(
    String action,
    Map<String, dynamic> requestBody,
  ) async {
    try {
      final endpoint = 'https://cognito-idp.$region.amazonaws.com/';
      final body = utf8.encode(jsonEncode(requestBody));

      // Create AWS HTTP Request
      final request = AWSHttpRequest(
        method: AWSHttpMethod.post,
        uri: Uri.parse(endpoint),
        headers: {
          AWSHeaders.target: 'AWSCognitoIdentityProviderService.$action',
          AWSHeaders.contentType: 'application/x-amz-json-1.1',
        },
        body: body,
      );

      // Sign the request using official AWS Signer
      final scope = AWSCredentialScope(
        region: region,
        service: AWSService.cognitoIdentityProvider,
      );

      final signedRequest = await _signer.sign(
        request,
        credentialScope: scope,
      );

      print('=== AWS Request ===');
      print('Action: $action');
      print('Endpoint: $endpoint');
      print('Body: ${jsonEncode(requestBody)}');

      // Send the request
      final response = await signedRequest.send().response;
      final responseBody = await response.decodeBody();

      print('Response Status: ${response.statusCode}');
      print('Response Body: $responseBody');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Operation successful',
          'data': responseBody.isNotEmpty ? jsonDecode(responseBody) : {},
        };
      } else {
        final errorBody = jsonDecode(responseBody);
        return {
          'success': false,
          'message': errorBody['__type'] ?? 'Unknown error',
          'details': errorBody,
        };
      }
    } catch (e, stackTrace) {
      print('Error making AWS request: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Request error: ${e.toString()}',
      };
    }
  }
}
