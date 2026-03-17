import 'user_plan.dart';

class PlanLimits {
  const PlanLimits({
    required this.maxFolders,
    required this.maxChats,
    required this.maxContextMessages,
    required this.responseDelaySeconds,
    required this.autoContextRefresh,
    required this.queuePriority,
  });

  final int maxFolders;
  final int maxChats;
  final int maxContextMessages;
  final int responseDelaySeconds;
  final bool autoContextRefresh;
  final int queuePriority;

  static PlanLimits forPlan(UserPlan plan) {
    switch (plan) {
      case UserPlan.free:
        return const PlanLimits(
          maxFolders: 1,
          maxChats: 5,
          maxContextMessages: 5,
          responseDelaySeconds: 10,
          autoContextRefresh: false,
          queuePriority: 1,
        );
      case UserPlan.plus:
        return const PlanLimits(
          maxFolders: 3,
          maxChats: 10,
          maxContextMessages: 20,
          responseDelaySeconds: 5,
          autoContextRefresh: true,
          queuePriority: 2,
        );
      case UserPlan.max:
        return const PlanLimits(
          maxFolders: 1000,
          maxChats: 1000,
          maxContextMessages: 50,
          responseDelaySeconds: 0,
          autoContextRefresh: true,
          queuePriority: 3,
        );
    }
  }
}
