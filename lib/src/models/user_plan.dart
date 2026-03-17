enum UserPlan { free, plus, max }

extension UserPlanX on UserPlan {
  static UserPlan parse(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'plus':
        return UserPlan.plus;
      case 'max':
        return UserPlan.max;
      case 'free':
      default:
        return UserPlan.free;
    }
  }

  String get code {
    switch (this) {
      case UserPlan.free:
        return 'free';
      case UserPlan.plus:
        return 'plus';
      case UserPlan.max:
        return 'max';
    }
  }

  String get title {
    switch (this) {
      case UserPlan.free:
        return 'Free';
      case UserPlan.plus:
        return 'Plus';
      case UserPlan.max:
        return 'Max';
    }
  }
}
