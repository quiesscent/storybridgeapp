// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppUserImpl _$$AppUserImplFromJson(Map<String, dynamic> json) =>
    _$AppUserImpl(
      name: json['name'] as String,
      email: json['email'] as String,
      avatar: json['avatar'] as String?,
    );

Map<String, dynamic> _$$AppUserImplToJson(_$AppUserImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'email': instance.email,
      'avatar': instance.avatar,
    };

_$AppStateImpl _$$AppStateImplFromJson(Map<String, dynamic> json) =>
    _$AppStateImpl(
      onboarded: json['onboarded'] as bool? ?? false,
      user: json['user'] == null
          ? null
          : AppUser.fromJson(json['user'] as Map<String, dynamic>),
      isGuest: json['isGuest'] as bool? ?? false,
      roles:
          (json['roles'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      lovedOnes:
          (json['lovedOnes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      textSize:
          $enumDecodeNullable(_$TextSizeEnumMap, json['textSize']) ??
          TextSize.large,
      appTextSize:
          $enumDecodeNullable(_$TextSizeEnumMap, json['appTextSize']) ??
          TextSize.medium,
      recordings:
          (json['recordings'] as List<dynamic>?)
              ?.map((e) => Recording.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      plan: $enumDecodeNullable(_$PlanEnumMap, json['plan']) ?? Plan.free,
    );

Map<String, dynamic> _$$AppStateImplToJson(_$AppStateImpl instance) =>
    <String, dynamic>{
      'onboarded': instance.onboarded,
      'user': instance.user,
      'isGuest': instance.isGuest,
      'roles': instance.roles,
      'lovedOnes': instance.lovedOnes,
      'textSize': _$TextSizeEnumMap[instance.textSize]!,
      'appTextSize': _$TextSizeEnumMap[instance.appTextSize]!,
      'recordings': instance.recordings,
      'plan': _$PlanEnumMap[instance.plan]!,
    };

const _$TextSizeEnumMap = {
  TextSize.small: 'small',
  TextSize.medium: 'medium',
  TextSize.large: 'large',
  TextSize.xlarge: 'xlarge',
};

const _$PlanEnumMap = {Plan.free: 'free', Plan.premium: 'premium'};

_$RecordingImpl _$$RecordingImplFromJson(Map<String, dynamic> json) =>
    _$RecordingImpl(
      id: json['id'] as String,
      storyId: json['storyId'] as String?,
      title: json['title'] as String,
      dedication: json['dedication'] as String? ?? '',
      format:
          $enumDecodeNullable(_$VideoFormatEnumMap, json['format']) ??
          VideoFormat.book,
      duration: json['duration'] as String,
      durationSeconds: (json['durationSeconds'] as num).toInt(),
      recordedAt: (json['recordedAt'] as num).toInt(),
      shared: json['shared'] as bool? ?? false,
      localVideoPath: json['localVideoPath'] as String?,
      localAudioPath: json['localAudioPath'] as String?,
      shareUrl: json['shareUrl'] as String?,
      settingsJson: json['settingsJson'] as String?,
      pageTimestampsJson: json['pageTimestampsJson'] as String?,
    );

Map<String, dynamic> _$$RecordingImplToJson(_$RecordingImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'storyId': instance.storyId,
      'title': instance.title,
      'dedication': instance.dedication,
      'format': _$VideoFormatEnumMap[instance.format]!,
      'duration': instance.duration,
      'durationSeconds': instance.durationSeconds,
      'recordedAt': instance.recordedAt,
      'shared': instance.shared,
      'localVideoPath': instance.localVideoPath,
      'localAudioPath': instance.localAudioPath,
      'shareUrl': instance.shareUrl,
      'settingsJson': instance.settingsJson,
      'pageTimestampsJson': instance.pageTimestampsJson,
    };

const _$VideoFormatEnumMap = {
  VideoFormat.face: 'face',
  VideoFormat.split: 'split',
  VideoFormat.book: 'book',
  VideoFormat.bookOnly: 'bookOnly',
  VideoFormat.audio: 'audio',
};
