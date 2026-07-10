// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AppUser _$AppUserFromJson(Map<String, dynamic> json) {
  return _AppUser.fromJson(json);
}

/// @nodoc
mixin _$AppUser {
  String get name => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  String? get avatar => throw _privateConstructorUsedError;

  /// Serializes this AppUser to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppUserCopyWith<AppUser> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppUserCopyWith<$Res> {
  factory $AppUserCopyWith(AppUser value, $Res Function(AppUser) then) =
      _$AppUserCopyWithImpl<$Res, AppUser>;
  @useResult
  $Res call({String name, String email, String? avatar});
}

/// @nodoc
class _$AppUserCopyWithImpl<$Res, $Val extends AppUser>
    implements $AppUserCopyWith<$Res> {
  _$AppUserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? email = null,
    Object? avatar = freezed,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            email: null == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String,
            avatar: freezed == avatar
                ? _value.avatar
                : avatar // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AppUserImplCopyWith<$Res> implements $AppUserCopyWith<$Res> {
  factory _$$AppUserImplCopyWith(
    _$AppUserImpl value,
    $Res Function(_$AppUserImpl) then,
  ) = __$$AppUserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, String email, String? avatar});
}

/// @nodoc
class __$$AppUserImplCopyWithImpl<$Res>
    extends _$AppUserCopyWithImpl<$Res, _$AppUserImpl>
    implements _$$AppUserImplCopyWith<$Res> {
  __$$AppUserImplCopyWithImpl(
    _$AppUserImpl _value,
    $Res Function(_$AppUserImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? email = null,
    Object? avatar = freezed,
  }) {
    return _then(
      _$AppUserImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        email: null == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String,
        avatar: freezed == avatar
            ? _value.avatar
            : avatar // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AppUserImpl implements _AppUser {
  const _$AppUserImpl({required this.name, required this.email, this.avatar});

  factory _$AppUserImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppUserImplFromJson(json);

  @override
  final String name;
  @override
  final String email;
  @override
  final String? avatar;

  @override
  String toString() {
    return 'AppUser(name: $name, email: $email, avatar: $avatar)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppUserImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.avatar, avatar) || other.avatar == avatar));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, email, avatar);

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppUserImplCopyWith<_$AppUserImpl> get copyWith =>
      __$$AppUserImplCopyWithImpl<_$AppUserImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AppUserImplToJson(this);
  }
}

abstract class _AppUser implements AppUser {
  const factory _AppUser({
    required final String name,
    required final String email,
    final String? avatar,
  }) = _$AppUserImpl;

  factory _AppUser.fromJson(Map<String, dynamic> json) = _$AppUserImpl.fromJson;

  @override
  String get name;
  @override
  String get email;
  @override
  String? get avatar;

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppUserImplCopyWith<_$AppUserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AppState _$AppStateFromJson(Map<String, dynamic> json) {
  return _AppState.fromJson(json);
}

/// @nodoc
mixin _$AppState {
  bool get onboarded => throw _privateConstructorUsedError;
  AppUser? get user => throw _privateConstructorUsedError;
  bool get isGuest => throw _privateConstructorUsedError;
  List<String> get roles => throw _privateConstructorUsedError;
  List<String> get lovedOnes => throw _privateConstructorUsedError;
  TextSize get textSize => throw _privateConstructorUsedError; // story body
  TextSize get appTextSize => throw _privateConstructorUsedError; // global UI
  List<Recording> get recordings => throw _privateConstructorUsedError;
  Plan get plan => throw _privateConstructorUsedError;

  /// Serializes this AppState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AppState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppStateCopyWith<AppState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppStateCopyWith<$Res> {
  factory $AppStateCopyWith(AppState value, $Res Function(AppState) then) =
      _$AppStateCopyWithImpl<$Res, AppState>;
  @useResult
  $Res call({
    bool onboarded,
    AppUser? user,
    bool isGuest,
    List<String> roles,
    List<String> lovedOnes,
    TextSize textSize,
    TextSize appTextSize,
    List<Recording> recordings,
    Plan plan,
  });

  $AppUserCopyWith<$Res>? get user;
}

/// @nodoc
class _$AppStateCopyWithImpl<$Res, $Val extends AppState>
    implements $AppStateCopyWith<$Res> {
  _$AppStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? onboarded = null,
    Object? user = freezed,
    Object? isGuest = null,
    Object? roles = null,
    Object? lovedOnes = null,
    Object? textSize = null,
    Object? appTextSize = null,
    Object? recordings = null,
    Object? plan = null,
  }) {
    return _then(
      _value.copyWith(
            onboarded: null == onboarded
                ? _value.onboarded
                : onboarded // ignore: cast_nullable_to_non_nullable
                      as bool,
            user: freezed == user
                ? _value.user
                : user // ignore: cast_nullable_to_non_nullable
                      as AppUser?,
            isGuest: null == isGuest
                ? _value.isGuest
                : isGuest // ignore: cast_nullable_to_non_nullable
                      as bool,
            roles: null == roles
                ? _value.roles
                : roles // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            lovedOnes: null == lovedOnes
                ? _value.lovedOnes
                : lovedOnes // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            textSize: null == textSize
                ? _value.textSize
                : textSize // ignore: cast_nullable_to_non_nullable
                      as TextSize,
            appTextSize: null == appTextSize
                ? _value.appTextSize
                : appTextSize // ignore: cast_nullable_to_non_nullable
                      as TextSize,
            recordings: null == recordings
                ? _value.recordings
                : recordings // ignore: cast_nullable_to_non_nullable
                      as List<Recording>,
            plan: null == plan
                ? _value.plan
                : plan // ignore: cast_nullable_to_non_nullable
                      as Plan,
          )
          as $Val,
    );
  }

  /// Create a copy of AppState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AppUserCopyWith<$Res>? get user {
    if (_value.user == null) {
      return null;
    }

    return $AppUserCopyWith<$Res>(_value.user!, (value) {
      return _then(_value.copyWith(user: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AppStateImplCopyWith<$Res>
    implements $AppStateCopyWith<$Res> {
  factory _$$AppStateImplCopyWith(
    _$AppStateImpl value,
    $Res Function(_$AppStateImpl) then,
  ) = __$$AppStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool onboarded,
    AppUser? user,
    bool isGuest,
    List<String> roles,
    List<String> lovedOnes,
    TextSize textSize,
    TextSize appTextSize,
    List<Recording> recordings,
    Plan plan,
  });

  @override
  $AppUserCopyWith<$Res>? get user;
}

/// @nodoc
class __$$AppStateImplCopyWithImpl<$Res>
    extends _$AppStateCopyWithImpl<$Res, _$AppStateImpl>
    implements _$$AppStateImplCopyWith<$Res> {
  __$$AppStateImplCopyWithImpl(
    _$AppStateImpl _value,
    $Res Function(_$AppStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? onboarded = null,
    Object? user = freezed,
    Object? isGuest = null,
    Object? roles = null,
    Object? lovedOnes = null,
    Object? textSize = null,
    Object? appTextSize = null,
    Object? recordings = null,
    Object? plan = null,
  }) {
    return _then(
      _$AppStateImpl(
        onboarded: null == onboarded
            ? _value.onboarded
            : onboarded // ignore: cast_nullable_to_non_nullable
                  as bool,
        user: freezed == user
            ? _value.user
            : user // ignore: cast_nullable_to_non_nullable
                  as AppUser?,
        isGuest: null == isGuest
            ? _value.isGuest
            : isGuest // ignore: cast_nullable_to_non_nullable
                  as bool,
        roles: null == roles
            ? _value._roles
            : roles // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        lovedOnes: null == lovedOnes
            ? _value._lovedOnes
            : lovedOnes // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        textSize: null == textSize
            ? _value.textSize
            : textSize // ignore: cast_nullable_to_non_nullable
                  as TextSize,
        appTextSize: null == appTextSize
            ? _value.appTextSize
            : appTextSize // ignore: cast_nullable_to_non_nullable
                  as TextSize,
        recordings: null == recordings
            ? _value._recordings
            : recordings // ignore: cast_nullable_to_non_nullable
                  as List<Recording>,
        plan: null == plan
            ? _value.plan
            : plan // ignore: cast_nullable_to_non_nullable
                  as Plan,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AppStateImpl implements _AppState {
  const _$AppStateImpl({
    this.onboarded = false,
    this.user,
    this.isGuest = false,
    final List<String> roles = const [],
    final List<String> lovedOnes = const [],
    this.textSize = TextSize.large,
    this.appTextSize = TextSize.medium,
    final List<Recording> recordings = const [],
    this.plan = Plan.free,
  }) : _roles = roles,
       _lovedOnes = lovedOnes,
       _recordings = recordings;

  factory _$AppStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppStateImplFromJson(json);

  @override
  @JsonKey()
  final bool onboarded;
  @override
  final AppUser? user;
  @override
  @JsonKey()
  final bool isGuest;
  final List<String> _roles;
  @override
  @JsonKey()
  List<String> get roles {
    if (_roles is EqualUnmodifiableListView) return _roles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_roles);
  }

  final List<String> _lovedOnes;
  @override
  @JsonKey()
  List<String> get lovedOnes {
    if (_lovedOnes is EqualUnmodifiableListView) return _lovedOnes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_lovedOnes);
  }

  @override
  @JsonKey()
  final TextSize textSize;
  // story body
  @override
  @JsonKey()
  final TextSize appTextSize;
  // global UI
  final List<Recording> _recordings;
  // global UI
  @override
  @JsonKey()
  List<Recording> get recordings {
    if (_recordings is EqualUnmodifiableListView) return _recordings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recordings);
  }

  @override
  @JsonKey()
  final Plan plan;

  @override
  String toString() {
    return 'AppState(onboarded: $onboarded, user: $user, isGuest: $isGuest, roles: $roles, lovedOnes: $lovedOnes, textSize: $textSize, appTextSize: $appTextSize, recordings: $recordings, plan: $plan)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppStateImpl &&
            (identical(other.onboarded, onboarded) ||
                other.onboarded == onboarded) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.isGuest, isGuest) || other.isGuest == isGuest) &&
            const DeepCollectionEquality().equals(other._roles, _roles) &&
            const DeepCollectionEquality().equals(
              other._lovedOnes,
              _lovedOnes,
            ) &&
            (identical(other.textSize, textSize) ||
                other.textSize == textSize) &&
            (identical(other.appTextSize, appTextSize) ||
                other.appTextSize == appTextSize) &&
            const DeepCollectionEquality().equals(
              other._recordings,
              _recordings,
            ) &&
            (identical(other.plan, plan) || other.plan == plan));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    onboarded,
    user,
    isGuest,
    const DeepCollectionEquality().hash(_roles),
    const DeepCollectionEquality().hash(_lovedOnes),
    textSize,
    appTextSize,
    const DeepCollectionEquality().hash(_recordings),
    plan,
  );

  /// Create a copy of AppState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppStateImplCopyWith<_$AppStateImpl> get copyWith =>
      __$$AppStateImplCopyWithImpl<_$AppStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AppStateImplToJson(this);
  }
}

abstract class _AppState implements AppState {
  const factory _AppState({
    final bool onboarded,
    final AppUser? user,
    final bool isGuest,
    final List<String> roles,
    final List<String> lovedOnes,
    final TextSize textSize,
    final TextSize appTextSize,
    final List<Recording> recordings,
    final Plan plan,
  }) = _$AppStateImpl;

  factory _AppState.fromJson(Map<String, dynamic> json) =
      _$AppStateImpl.fromJson;

  @override
  bool get onboarded;
  @override
  AppUser? get user;
  @override
  bool get isGuest;
  @override
  List<String> get roles;
  @override
  List<String> get lovedOnes;
  @override
  TextSize get textSize; // story body
  @override
  TextSize get appTextSize; // global UI
  @override
  List<Recording> get recordings;
  @override
  Plan get plan;

  /// Create a copy of AppState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppStateImplCopyWith<_$AppStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Recording _$RecordingFromJson(Map<String, dynamic> json) {
  return _Recording.fromJson(json);
}

/// @nodoc
mixin _$Recording {
  String get id => throw _privateConstructorUsedError;
  String? get storyId =>
      throw _privateConstructorUsedError; // null = "own story"
  String get title => throw _privateConstructorUsedError;
  String get dedication => throw _privateConstructorUsedError;
  VideoFormat get format => throw _privateConstructorUsedError;
  String get duration =>
      throw _privateConstructorUsedError; // "1 min", "45 sec"
  int get durationSeconds => throw _privateConstructorUsedError;
  int get recordedAt => throw _privateConstructorUsedError; // epoch ms
  bool get shared => throw _privateConstructorUsedError;
  String? get localVideoPath =>
      throw _privateConstructorUsedError; // path on device
  String? get localAudioPath => throw _privateConstructorUsedError;
  String? get shareUrl => throw _privateConstructorUsedError;
  String? get settingsJson => throw _privateConstructorUsedError;
  String? get pageTimestampsJson => throw _privateConstructorUsedError;

  /// Serializes this Recording to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Recording
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecordingCopyWith<Recording> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecordingCopyWith<$Res> {
  factory $RecordingCopyWith(Recording value, $Res Function(Recording) then) =
      _$RecordingCopyWithImpl<$Res, Recording>;
  @useResult
  $Res call({
    String id,
    String? storyId,
    String title,
    String dedication,
    VideoFormat format,
    String duration,
    int durationSeconds,
    int recordedAt,
    bool shared,
    String? localVideoPath,
    String? localAudioPath,
    String? shareUrl,
    String? settingsJson,
    String? pageTimestampsJson,
  });
}

/// @nodoc
class _$RecordingCopyWithImpl<$Res, $Val extends Recording>
    implements $RecordingCopyWith<$Res> {
  _$RecordingCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Recording
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? storyId = freezed,
    Object? title = null,
    Object? dedication = null,
    Object? format = null,
    Object? duration = null,
    Object? durationSeconds = null,
    Object? recordedAt = null,
    Object? shared = null,
    Object? localVideoPath = freezed,
    Object? localAudioPath = freezed,
    Object? shareUrl = freezed,
    Object? settingsJson = freezed,
    Object? pageTimestampsJson = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            storyId: freezed == storyId
                ? _value.storyId
                : storyId // ignore: cast_nullable_to_non_nullable
                      as String?,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            dedication: null == dedication
                ? _value.dedication
                : dedication // ignore: cast_nullable_to_non_nullable
                      as String,
            format: null == format
                ? _value.format
                : format // ignore: cast_nullable_to_non_nullable
                      as VideoFormat,
            duration: null == duration
                ? _value.duration
                : duration // ignore: cast_nullable_to_non_nullable
                      as String,
            durationSeconds: null == durationSeconds
                ? _value.durationSeconds
                : durationSeconds // ignore: cast_nullable_to_non_nullable
                      as int,
            recordedAt: null == recordedAt
                ? _value.recordedAt
                : recordedAt // ignore: cast_nullable_to_non_nullable
                      as int,
            shared: null == shared
                ? _value.shared
                : shared // ignore: cast_nullable_to_non_nullable
                      as bool,
            localVideoPath: freezed == localVideoPath
                ? _value.localVideoPath
                : localVideoPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            localAudioPath: freezed == localAudioPath
                ? _value.localAudioPath
                : localAudioPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            shareUrl: freezed == shareUrl
                ? _value.shareUrl
                : shareUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            settingsJson: freezed == settingsJson
                ? _value.settingsJson
                : settingsJson // ignore: cast_nullable_to_non_nullable
                      as String?,
            pageTimestampsJson: freezed == pageTimestampsJson
                ? _value.pageTimestampsJson
                : pageTimestampsJson // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecordingImplCopyWith<$Res>
    implements $RecordingCopyWith<$Res> {
  factory _$$RecordingImplCopyWith(
    _$RecordingImpl value,
    $Res Function(_$RecordingImpl) then,
  ) = __$$RecordingImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String? storyId,
    String title,
    String dedication,
    VideoFormat format,
    String duration,
    int durationSeconds,
    int recordedAt,
    bool shared,
    String? localVideoPath,
    String? localAudioPath,
    String? shareUrl,
    String? settingsJson,
    String? pageTimestampsJson,
  });
}

/// @nodoc
class __$$RecordingImplCopyWithImpl<$Res>
    extends _$RecordingCopyWithImpl<$Res, _$RecordingImpl>
    implements _$$RecordingImplCopyWith<$Res> {
  __$$RecordingImplCopyWithImpl(
    _$RecordingImpl _value,
    $Res Function(_$RecordingImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Recording
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? storyId = freezed,
    Object? title = null,
    Object? dedication = null,
    Object? format = null,
    Object? duration = null,
    Object? durationSeconds = null,
    Object? recordedAt = null,
    Object? shared = null,
    Object? localVideoPath = freezed,
    Object? localAudioPath = freezed,
    Object? shareUrl = freezed,
    Object? settingsJson = freezed,
    Object? pageTimestampsJson = freezed,
  }) {
    return _then(
      _$RecordingImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        storyId: freezed == storyId
            ? _value.storyId
            : storyId // ignore: cast_nullable_to_non_nullable
                  as String?,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        dedication: null == dedication
            ? _value.dedication
            : dedication // ignore: cast_nullable_to_non_nullable
                  as String,
        format: null == format
            ? _value.format
            : format // ignore: cast_nullable_to_non_nullable
                  as VideoFormat,
        duration: null == duration
            ? _value.duration
            : duration // ignore: cast_nullable_to_non_nullable
                  as String,
        durationSeconds: null == durationSeconds
            ? _value.durationSeconds
            : durationSeconds // ignore: cast_nullable_to_non_nullable
                  as int,
        recordedAt: null == recordedAt
            ? _value.recordedAt
            : recordedAt // ignore: cast_nullable_to_non_nullable
                  as int,
        shared: null == shared
            ? _value.shared
            : shared // ignore: cast_nullable_to_non_nullable
                  as bool,
        localVideoPath: freezed == localVideoPath
            ? _value.localVideoPath
            : localVideoPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        localAudioPath: freezed == localAudioPath
            ? _value.localAudioPath
            : localAudioPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        shareUrl: freezed == shareUrl
            ? _value.shareUrl
            : shareUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        settingsJson: freezed == settingsJson
            ? _value.settingsJson
            : settingsJson // ignore: cast_nullable_to_non_nullable
                  as String?,
        pageTimestampsJson: freezed == pageTimestampsJson
            ? _value.pageTimestampsJson
            : pageTimestampsJson // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RecordingImpl implements _Recording {
  const _$RecordingImpl({
    required this.id,
    this.storyId,
    required this.title,
    this.dedication = '',
    this.format = VideoFormat.book,
    required this.duration,
    required this.durationSeconds,
    required this.recordedAt,
    this.shared = false,
    this.localVideoPath,
    this.localAudioPath,
    this.shareUrl,
    this.settingsJson,
    this.pageTimestampsJson,
  });

  factory _$RecordingImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecordingImplFromJson(json);

  @override
  final String id;
  @override
  final String? storyId;
  // null = "own story"
  @override
  final String title;
  @override
  @JsonKey()
  final String dedication;
  @override
  @JsonKey()
  final VideoFormat format;
  @override
  final String duration;
  // "1 min", "45 sec"
  @override
  final int durationSeconds;
  @override
  final int recordedAt;
  // epoch ms
  @override
  @JsonKey()
  final bool shared;
  @override
  final String? localVideoPath;
  // path on device
  @override
  final String? localAudioPath;
  @override
  final String? shareUrl;
  @override
  final String? settingsJson;
  @override
  final String? pageTimestampsJson;

  @override
  String toString() {
    return 'Recording(id: $id, storyId: $storyId, title: $title, dedication: $dedication, format: $format, duration: $duration, durationSeconds: $durationSeconds, recordedAt: $recordedAt, shared: $shared, localVideoPath: $localVideoPath, localAudioPath: $localAudioPath, shareUrl: $shareUrl, settingsJson: $settingsJson, pageTimestampsJson: $pageTimestampsJson)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecordingImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.storyId, storyId) || other.storyId == storyId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.dedication, dedication) ||
                other.dedication == dedication) &&
            (identical(other.format, format) || other.format == format) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.durationSeconds, durationSeconds) ||
                other.durationSeconds == durationSeconds) &&
            (identical(other.recordedAt, recordedAt) ||
                other.recordedAt == recordedAt) &&
            (identical(other.shared, shared) || other.shared == shared) &&
            (identical(other.localVideoPath, localVideoPath) ||
                other.localVideoPath == localVideoPath) &&
            (identical(other.localAudioPath, localAudioPath) ||
                other.localAudioPath == localAudioPath) &&
            (identical(other.shareUrl, shareUrl) ||
                other.shareUrl == shareUrl) &&
            (identical(other.settingsJson, settingsJson) ||
                other.settingsJson == settingsJson) &&
            (identical(other.pageTimestampsJson, pageTimestampsJson) ||
                other.pageTimestampsJson == pageTimestampsJson));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    storyId,
    title,
    dedication,
    format,
    duration,
    durationSeconds,
    recordedAt,
    shared,
    localVideoPath,
    localAudioPath,
    shareUrl,
    settingsJson,
    pageTimestampsJson,
  );

  /// Create a copy of Recording
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecordingImplCopyWith<_$RecordingImpl> get copyWith =>
      __$$RecordingImplCopyWithImpl<_$RecordingImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RecordingImplToJson(this);
  }
}

abstract class _Recording implements Recording {
  const factory _Recording({
    required final String id,
    final String? storyId,
    required final String title,
    final String dedication,
    final VideoFormat format,
    required final String duration,
    required final int durationSeconds,
    required final int recordedAt,
    final bool shared,
    final String? localVideoPath,
    final String? localAudioPath,
    final String? shareUrl,
    final String? settingsJson,
    final String? pageTimestampsJson,
  }) = _$RecordingImpl;

  factory _Recording.fromJson(Map<String, dynamic> json) =
      _$RecordingImpl.fromJson;

  @override
  String get id;
  @override
  String? get storyId; // null = "own story"
  @override
  String get title;
  @override
  String get dedication;
  @override
  VideoFormat get format;
  @override
  String get duration; // "1 min", "45 sec"
  @override
  int get durationSeconds;
  @override
  int get recordedAt; // epoch ms
  @override
  bool get shared;
  @override
  String? get localVideoPath; // path on device
  @override
  String? get localAudioPath;
  @override
  String? get shareUrl;
  @override
  String? get settingsJson;
  @override
  String? get pageTimestampsJson;

  /// Create a copy of Recording
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecordingImplCopyWith<_$RecordingImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
