/// Role-based routing per assignment section 3.1.
class RoleConfig {
  static String homeForRole(String role) {
    switch (role) {
      case 'Admin':
        return '/dashboard';
      case 'Clinician':
        return '/dashboard';
      case 'Tech':
        return '/dashboard';
      default:
        return '/dashboard';
    }
  }

  static bool canManagePatients(String role) =>
      role == 'Admin' || role == 'Clinician';

  static bool canManageDevices(String role) =>
      role == 'Admin' || role == 'Tech';

  static bool canAcknowledgeAlerts(String role) =>
      role == 'Admin' || role == 'Clinician';

  static bool canStartSessions(String role) =>
      role == 'Admin' || role == 'Clinician' || role == 'Tech';
}
