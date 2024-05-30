import 'package:darq/darq.dart';
import 'package:dartx/dartx.dart' hide StringCapitalizeExtension;
import 'package:get_it/get_it.dart';
import 'package:neat_cache/neat_cache.dart';
import 'package:nyxx/nyxx.dart' hide Cache;
import 'package:nyxx_commands/nyxx_commands.dart' hide id;

import '../database.dart' hide Guild;

extension ContextExtension on ChatContext {
  Future<Message> send(String content) => respond(MessageBuilder(content: content));

  /// Returns the bot's prefix or '/' if this was invoked from an interaction.
  String get realPrefix => this is InteractionChatContext ? '/' : (this as MessageChatContext).prefix;
}

extension GuildExtensions on Guild {
  Future<Member> get me => members.get(manager.client.user.id);

  Map<Snowflake, GuildChannel> get channels => manager.client.channels.cache.entries
      .where((e) => e.value is GuildChannel && (e.value as GuildChannel).guildId == id)
      .toMap((e) => e as MapEntry<Snowflake, GuildChannel>);

  Map<String, Object?> toJson() => {
        'id': id.toString(),
        'name': name,
        'icon': iconHash,
        'splash': splashHash,
        'discovery_splash': discoverySplashHash,
        'owner_id': ownerId.toString(),
        'afk_channel_id': afkChannelId?.toString(),
        'afk_timeout': afkTimeout.inSeconds,
        'widget_enabled': isWidgetEnabled,
        'widget_channel_id': widgetChannelId?.toString(),
        'verification_level': verificationLevel.value,
        'default_message_notifications': defaultMessageNotificationLevel.value,
        'explicit_content_filter': explicitContentFilterLevel.value,
        'roles': roles.cache.values.map((e) => e.toJson()).toList(),
        'emojis': emojis.cache.values.map((e) => (e as GuildEmoji).toJson()).toList(),
        'features': features.map((e) => e.value).toList(),
        'mfa_level': mfaLevel.value,
        'application_id': applicationId?.toString(),
        'system_channel_id': systemChannelId?.toString(),
        'system_channel_flags': systemChannelFlags.value,
        'rules_channel_id': rulesChannelId?.toString(),
        'max_presences': maxPresences,
        'max_members': maxMembers,
        'vanity_url_code': vanityUrlCode,
        'description': description,
        'banner': bannerHash,
        'premium_tier': premiumTier.value,
        'premium_subscription_count': premiumSubscriptionCount,
        'preferred_locale': preferredLocale.identifier,
        'public_updates_channel_id': publicUpdatesChannelId?.toString(),
        'max_video_channel_users': maxVideoChannelUsers,
        'max_stage_video_channel_users': maxStageChannelUsers,
        'approximate_member_count': approximateMemberCount,
        'approximate_presence_count': approximatePresenceCount,
        'welcome_screen': welcomeScreen?.toJson(),
        'nsfw_level': nsfwLevel.value,
        'stickers': stickers.cache.values.map((e) => e.toJson()).toList(),
        'premium_progress_bar_enabled': hasPremiumProgressBarEnabled,
        'safety_alerts_channel_id': safetyAlertsChannelId?.toString(),
      };
}

extension StickersExtension on GuildSticker {
  Map<String, Object?> toJson() => {
        'id': id.toString(),
        'name': name,
        'description': description,
        'tags': tags,
        'asset': '',
        'format_type': formatType.value,
        'available': available,
        'guild_id': guildId.toString(),
        'type': type.value,
        'sort_value': sortValue,
      };
}

extension WelcomeScreenExtensions on WelcomeScreen {
  Map<String, Object?> toJson() => {
        'description': description,
        'welcome_channels': channels.map((e) => e.toJson()).toList(),
      };
}

extension WelcomeScreenChannelExtensions on WelcomeScreenChannel {
  Map<String, Object?> toJson() => {
        'channel_id': channelId.toString(),
        'description': description,
        'emoji_id': emojiId?.toString(),
        'emoji_name': emojiName,
      };
}

extension EmojisExtension on GuildEmoji {
  Map<String, Object?> toJson() => {
        'id': id.toString(),
        'name': name,
        'roles': roles?.map((e) => e.id.toString()).toList(),
        'user': user?.toJson(),
        'require_colons': requiresColons,
        'managed': isManaged,
        'animated': isAnimated,
        'available': isAvailable,
      };
}

extension RoleExtensions on Role {
  Map<String, Object?> toJson() => {
        'id': id.toString(),
        'name': name,
        'color': color.value,
        'hoist': isHoisted,
        'position': position,
        'permissions': permissions.value.toString(),
        'mentionable': isMentionable,
        'tags': tags?.toJson(),
      };
}

extension RoleTagsExtensions on RoleTags {
  Map<String, Object?> toJson() => {
        'bot_id': botId?.toString(),
        'integration_id': integrationId?.toString(),
        'premium_subscriber': isPremiumSubscriber,
        'subscription_listing_id': subscriptionListingId?.toString(),
        'available_for_purchase': isAvailableForPurchase,
        'guild_connections': isLinkedRole,
      };
}

extension MemberExtensions on Member {
  Guild? get guild => manager.client.guilds.cache[manager.guildId];

  Future<bool> get isManageable async {
    if (id == guild?.ownerId) {
      return false;
    }

    if (id == manager.client.user.id) {
      return false;
    }

    if (manager.client.user.id == guild?.ownerId) {
      return true;
    }

    final me = await guild!.me;

    final meHighestRole = await me.highestRole;
    final highestRole = await this.highestRole;

    return ((meHighestRole?.position ?? 0).compareTo(highestRole?.position ?? 0) > 0);
  }

  Future<bool> get isUnmanageable async => !await isManageable;

  Future<Permissions> get computedPermissions async {
    Future<Permissions> computeBasePermissions() async {
      if (guild?.ownerId == id) {
        return Permissions.allPermissions;
      }

      final everyoneRole = await guild!.roles[guild!.id].get();
      Flags<Permissions> permissions = everyoneRole.permissions;

      for (final role in roles) {
        final rolePermissions = (await role.get()).permissions;

        permissions |= rolePermissions;
      }

      permissions = Permissions(permissions.value);
      permissions as Permissions;

      if (permissions.isAdministrator) {
        return Permissions.allPermissions;
      }

      return permissions;
    }

    return computeBasePermissions();
  }

  Future<bool> get isBannable async {
    if (guild == null) {
      return false;
    }

    final me = await guild!.me;

    final mePermissions = await me.computedPermissions;
    final isManageable = await this.isManageable;

    final canBan = (mePermissions.canBanMembers || mePermissions.isAdministrator);

    return canBan && isManageable;
  }

  Future<bool> get isUnbannable async => !await isBannable;

  Future<List<Role>> get resolvedRoles async => Future.wait(roles.map((e) => guild!.roles.get(e.id)));

  Future<Message> sendMessage(MessageBuilder builder) async => (user ?? await manager.client.users.get(id)).sendMessage(builder);
}

extension HighestRoleExtension on Member {
  Future<Role?> get highestRole async {
    final roles = await resolvedRoles;
    return roles.isEmpty ? null : roles.reduce((a, b) => a.position > b.position ? a : b);
  }
}

extension ChatCommandExtension on ChatCommand {
  ChatCommandComponent get root {
    dynamic parent = this;
    while (parent.parent != null) {
      if (parent.parent is CommandsPlugin) {
        break;
      }

      parent = parent.parent!;
    }
    return parent;
  }
}

extension UserExtension on User {
  String get tag => discriminator == '0' ? username : '$username#$discriminator';

  DmChannel? get dm => manager.client.channels.cache.values.firstOrNullWhere((e) => e is DmChannel && e.recipient.id == id) as DmChannel?;

  Future<Message> sendMessage(MessageBuilder builder) async => (dm ?? await manager.createDm(id)).sendMessage(builder);

  Map<String, Object?> toJson() => {
        'id': id.toString(),
        'username': username,
        'discriminator': discriminator,
        'global_name': globalName,
        'avatar': avatarHash,
        'bot': isBot,
        'system': isSystem,
        'mfa_enabled': hasMfaEnabled,
        'banner': bannerHash,
        'accent_color': accentColor?.toHexString(),
        'locale': locale?.identifier,
        'flags': flags?.value,
        'public_flags': publicFlags?.value,
        'avatar_decoration': avatarDecorationHash,
      };
}

extension FutureErrorNullable<T> on Future<T> {
  Future<T?> silentCatchAsNull() async {
    try {
      return await this;
    } catch (_) {
      return null;
    }
  }
}

// extension ThreadExtension on Thread {
//   // GuildTextChannel get parent => client.channels[p
// }

extension EmbedBuilderBetter on EmbedBuilder {
  void addBlankField({bool isInline = false}) => addField(
        name: '\u200b',
        value: '\u200b',
        isInline: isInline,
      );

  void addField({required String name, required String value, bool isInline = false}) => (fields ?? (fields = [])).add(
        EmbedFieldBuilder(
          name: name,
          value: value,
          isInline: isInline,
        ),
      );

  void maybeAddField({String? name, String? value, bool isInline = false}) {
    if (name != null && value != null) {
      addField(name: name, value: value, isInline: isInline);
    }
  }
}

extension ListExtension<E> on List<E> {
  String joinWithStep([String separator = '', int step = 1, String inBetween = ' ']) {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i += step) {
      buffer.write(this[i]);
      if (i + step < length) {
        buffer.write(separator);
      }
    }
    return buffer.toString();
  }
}

extension SnowflakeExtension on Snowflake {
  /// Converts a [Snowflake] to a [BigInt].
  BigInt toBigInt() => BigInt.from(value);
}

extension SnowflakeInt on int {
  Snowflake get snowflake => Snowflake(this);
}

extension SnowflakeString on String {
  Snowflake get snowflake => Snowflake.parse(this);
}

extension StringExtension on String {
  String get capitalize => '${this[0].toUpperCase()}${substring(1)}';
  String get firstLetterUpperCase => '${this[0].toUpperCase()}${substring(1)}';
  String get title => splitMapJoin(' ', onNonMatch: (s) => s.capitalize, onMatch: (s) => s[0]!);
}

extension ClientExtensions on NyxxRest {
  AppDatabase get db => GetIt.I.get<AppDatabase>();
  Cache<String> get cache => GetIt.I.get<Cache<String>>();
}
