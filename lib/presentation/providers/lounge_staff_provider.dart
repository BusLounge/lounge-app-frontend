import 'package:flutter/foundation.dart';
import '../../domain/entities/lounge_staff.dart';
import '../../data/datasources/lounge_staff_remote_datasource.dart';
import '../../core/error/exceptions.dart';

/// Provider: Lounge Staff Management
/// Manages UI state for lounge staff operations
class LoungeStaffProvider extends ChangeNotifier {
  final LoungeStaffRemoteDataSource remoteDataSource;

  LoungeStaffProvider({required this.remoteDataSource});

  // UI State
  bool _isLoading = false;
  String? _error;
  List<LoungeStaff> _staffList = [];
  LoungeStaff? _selectedStaff;
  String? _lastLoungeId;
  String? _lastApprovalStatus;
  String? _lastEmploymentStatus;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<LoungeStaff> get staffList => _staffList;
  LoungeStaff? get selectedStaff => _selectedStaff;

  // Filter getters
  bool _isApprovalActive(LoungeStaff staff) {
    return staff.approvalStatus == 'approved';
  }

  List<LoungeStaff> get approvedStaff =>
      _staffList.where((s) => _isApprovalActive(s)).toList();
  List<LoungeStaff> get pendingStaff =>
      _staffList.where((s) => s.approvalStatus == 'pending').toList();
  List<LoungeStaff> get activeStaff =>
      _staffList.where((s) => _isApprovalActive(s) && s.isActive).toList();

  /// Add staff member directly (Owner only)
  Future<bool> addStaffDirectly({
    required String loungeId,
    required String fullName,
    required String nicNumber,
    required String phone,
    required String email,
    required DateTime hiredDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final staff = await remoteDataSource.addStaffDirectly(
        loungeId: loungeId,
        fullName: fullName,
        nicNumber: nicNumber,
        phone: phone,
        email: email,
        hiredDate: hiredDate,
      );

      // Add to local list
      _staffList.add(staff);
      _selectedStaff = staff;

      _isLoading = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get all staff for a lounge
  Future<bool> getStaffByLounge({
    required String loungeId,
    String? approvalStatus,
    String? employmentStatus,
    bool showLoading = true,
  }) async {
    _lastLoungeId = loungeId;
    _lastApprovalStatus = approvalStatus;
    _lastEmploymentStatus = employmentStatus;

    if (showLoading) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final staffModels = await remoteDataSource.getStaffByLounge(
        loungeId: loungeId,
        approvalStatus: approvalStatus,
        employmentStatus: employmentStatus,
      );

      _staffList = staffModels;
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
      return true;
    } on AppException catch (e) {
      if (showLoading) {
        _error = e.message;
        _isLoading = false;
        notifyListeners();
      }
      return false;
    } catch (e) {
      if (showLoading) {
        _error = 'An unexpected error occurred';
        _isLoading = false;
        notifyListeners();
      }
      return false;
    }
  }

  /// Get staff filtered by approval status
  Future<bool> getStaffByApprovalStatus({
    required String loungeId,
    required String approvalStatus,
    bool showLoading = true,
  }) async {
    _lastLoungeId = loungeId;
    _lastApprovalStatus = approvalStatus;
    _lastEmploymentStatus = null;

    if (showLoading) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final staffModels = await remoteDataSource.getStaffByApprovalStatus(
        loungeId: loungeId,
        approvalStatus: approvalStatus,
      );

      _staffList = staffModels;
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
      return true;
    } on AppException catch (e) {
      if (showLoading) {
        _error = e.message;
        _isLoading = false;
        notifyListeners();
      }
      return false;
    } catch (e) {
      if (showLoading) {
        _error = 'An unexpected error occurred';
        _isLoading = false;
        notifyListeners();
      }
      return false;
    }
  }

  /// Approve or decline a staff member (Owner only)
  Future<bool> updateStaffApproval({
    required String loungeId,
    required String staffId,
    required String approvalStatus,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await remoteDataSource.updateStaffApproval(
        loungeId: loungeId,
        staffId: staffId,
        approvalStatus: approvalStatus,
      );

      _staffList = _staffList.map((staff) {
        if (staff.id == staffId) {
          return staff.copyWith(
            approvalStatus: approvalStatus,
            employmentStatus:
                approvalStatus == 'approved' ? 'active' : 'inactive',
            hiredDate: approvalStatus == 'approved' ? DateTime.now() : null,
            updatedAt: DateTime.now(),
          );
        }
        return staff;
      }).toList();
      return true;
    } on AppException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Remove a staff member from lounge (Owner only)
  Future<bool> removeStaff({
    required String loungeId,
    required String staffId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await remoteDataSource.removeStaff(loungeId: loungeId, staffId: staffId);
      _staffList.removeWhere((staff) => staff.id == staffId);
      return true;
    } on AppException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get my staff profile (Staff member view)
  Future<bool> getMyStaffProfile({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final staff = await remoteDataSource.getMyStaffProfile();
      _selectedStaff = staff;
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _error = e.message;
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshLastQuery({bool showLoading = false}) async {
    if (_lastLoungeId == null) {
      return;
    }

    if (_lastApprovalStatus != null) {
      await getStaffByApprovalStatus(
        loungeId: _lastLoungeId!,
        approvalStatus: _lastApprovalStatus!,
        showLoading: showLoading,
      );
      return;
    }

    await getStaffByLounge(
      loungeId: _lastLoungeId!,
      employmentStatus: _lastEmploymentStatus,
      showLoading: showLoading,
    );
  }

  Future<void> refreshForLounge(
    String loungeId, {
    bool showLoading = false,
  }) async {
    if (_lastApprovalStatus != null) {
      await getStaffByApprovalStatus(
        loungeId: loungeId,
        approvalStatus: _lastApprovalStatus!,
        showLoading: showLoading,
      );
      return;
    }

    await getStaffByLounge(
      loungeId: loungeId,
      employmentStatus: _lastEmploymentStatus,
      showLoading: showLoading,
    );
  }

  /// Update my staff profile
  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? nicNumber,
    String? email,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await remoteDataSource.updateProfile(
        fullName: fullName,
        phone: phone,
        nicNumber: nicNumber,
        email: email,
        notes: notes,
      );

      // Update selected staff with new data
      if (_selectedStaff != null) {
        _selectedStaff = _selectedStaff!.copyWith(
          fullName: fullName ?? _selectedStaff!.fullName,
          phone: phone ?? _selectedStaff!.phone,
          nicNumber: nicNumber ?? _selectedStaff!.nicNumber,
          email: email ?? _selectedStaff!.email,
          notes: notes ?? _selectedStaff!.notes,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to update profile: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Reset provider state
  void reset() {
    _isLoading = false;
    _error = null;
    _staffList = [];
    _selectedStaff = null;
    _lastLoungeId = null;
    _lastApprovalStatus = null;
    _lastEmploymentStatus = null;
    notifyListeners();
  }
}
