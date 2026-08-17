// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'client.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$HostEventDto {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<SessionMetaDto> field0) sessions,
    required TResult Function(UpdateDto field0) update,
    required TResult Function(String session, bool running) status,
    required TResult Function(PermissionReqDto field0) permission,
    required TResult Function() disconnected,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<SessionMetaDto> field0)? sessions,
    TResult? Function(UpdateDto field0)? update,
    TResult? Function(String session, bool running)? status,
    TResult? Function(PermissionReqDto field0)? permission,
    TResult? Function()? disconnected,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<SessionMetaDto> field0)? sessions,
    TResult Function(UpdateDto field0)? update,
    TResult Function(String session, bool running)? status,
    TResult Function(PermissionReqDto field0)? permission,
    TResult Function()? disconnected,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(HostEventDto_Sessions value) sessions,
    required TResult Function(HostEventDto_Update value) update,
    required TResult Function(HostEventDto_Status value) status,
    required TResult Function(HostEventDto_Permission value) permission,
    required TResult Function(HostEventDto_Disconnected value) disconnected,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(HostEventDto_Sessions value)? sessions,
    TResult? Function(HostEventDto_Update value)? update,
    TResult? Function(HostEventDto_Status value)? status,
    TResult? Function(HostEventDto_Permission value)? permission,
    TResult? Function(HostEventDto_Disconnected value)? disconnected,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(HostEventDto_Sessions value)? sessions,
    TResult Function(HostEventDto_Update value)? update,
    TResult Function(HostEventDto_Status value)? status,
    TResult Function(HostEventDto_Permission value)? permission,
    TResult Function(HostEventDto_Disconnected value)? disconnected,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HostEventDtoCopyWith<$Res> {
  factory $HostEventDtoCopyWith(
    HostEventDto value,
    $Res Function(HostEventDto) then,
  ) = _$HostEventDtoCopyWithImpl<$Res, HostEventDto>;
}

/// @nodoc
class _$HostEventDtoCopyWithImpl<$Res, $Val extends HostEventDto>
    implements $HostEventDtoCopyWith<$Res> {
  _$HostEventDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HostEventDto
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$HostEventDto_SessionsImplCopyWith<$Res> {
  factory _$$HostEventDto_SessionsImplCopyWith(
    _$HostEventDto_SessionsImpl value,
    $Res Function(_$HostEventDto_SessionsImpl) then,
  ) = __$$HostEventDto_SessionsImplCopyWithImpl<$Res>;
  @useResult
  $Res call({List<SessionMetaDto> field0});
}

/// @nodoc
class __$$HostEventDto_SessionsImplCopyWithImpl<$Res>
    extends _$HostEventDtoCopyWithImpl<$Res, _$HostEventDto_SessionsImpl>
    implements _$$HostEventDto_SessionsImplCopyWith<$Res> {
  __$$HostEventDto_SessionsImplCopyWithImpl(
    _$HostEventDto_SessionsImpl _value,
    $Res Function(_$HostEventDto_SessionsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HostEventDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$HostEventDto_SessionsImpl(
        null == field0
            ? _value._field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as List<SessionMetaDto>,
      ),
    );
  }
}

/// @nodoc

class _$HostEventDto_SessionsImpl extends HostEventDto_Sessions {
  const _$HostEventDto_SessionsImpl(final List<SessionMetaDto> field0)
    : _field0 = field0,
      super._();

  final List<SessionMetaDto> _field0;
  @override
  List<SessionMetaDto> get field0 {
    if (_field0 is EqualUnmodifiableListView) return _field0;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_field0);
  }

  @override
  String toString() {
    return 'HostEventDto.sessions(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HostEventDto_SessionsImpl &&
            const DeepCollectionEquality().equals(other._field0, _field0));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_field0));

  /// Create a copy of HostEventDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HostEventDto_SessionsImplCopyWith<_$HostEventDto_SessionsImpl>
  get copyWith =>
      __$$HostEventDto_SessionsImplCopyWithImpl<_$HostEventDto_SessionsImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<SessionMetaDto> field0) sessions,
    required TResult Function(UpdateDto field0) update,
    required TResult Function(String session, bool running) status,
    required TResult Function(PermissionReqDto field0) permission,
    required TResult Function() disconnected,
  }) {
    return sessions(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<SessionMetaDto> field0)? sessions,
    TResult? Function(UpdateDto field0)? update,
    TResult? Function(String session, bool running)? status,
    TResult? Function(PermissionReqDto field0)? permission,
    TResult? Function()? disconnected,
  }) {
    return sessions?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<SessionMetaDto> field0)? sessions,
    TResult Function(UpdateDto field0)? update,
    TResult Function(String session, bool running)? status,
    TResult Function(PermissionReqDto field0)? permission,
    TResult Function()? disconnected,
    required TResult orElse(),
  }) {
    if (sessions != null) {
      return sessions(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(HostEventDto_Sessions value) sessions,
    required TResult Function(HostEventDto_Update value) update,
    required TResult Function(HostEventDto_Status value) status,
    required TResult Function(HostEventDto_Permission value) permission,
    required TResult Function(HostEventDto_Disconnected value) disconnected,
  }) {
    return sessions(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(HostEventDto_Sessions value)? sessions,
    TResult? Function(HostEventDto_Update value)? update,
    TResult? Function(HostEventDto_Status value)? status,
    TResult? Function(HostEventDto_Permission value)? permission,
    TResult? Function(HostEventDto_Disconnected value)? disconnected,
  }) {
    return sessions?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(HostEventDto_Sessions value)? sessions,
    TResult Function(HostEventDto_Update value)? update,
    TResult Function(HostEventDto_Status value)? status,
    TResult Function(HostEventDto_Permission value)? permission,
    TResult Function(HostEventDto_Disconnected value)? disconnected,
    required TResult orElse(),
  }) {
    if (sessions != null) {
      return sessions(this);
    }
    return orElse();
  }
}

abstract class HostEventDto_Sessions extends HostEventDto {
  const factory HostEventDto_Sessions(final List<SessionMetaDto> field0) =
      _$HostEventDto_SessionsImpl;
  const HostEventDto_Sessions._() : super._();

  List<SessionMetaDto> get field0;

  /// Create a copy of HostEventDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HostEventDto_SessionsImplCopyWith<_$HostEventDto_SessionsImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$HostEventDto_UpdateImplCopyWith<$Res> {
  factory _$$HostEventDto_UpdateImplCopyWith(
    _$HostEventDto_UpdateImpl value,
    $Res Function(_$HostEventDto_UpdateImpl) then,
  ) = __$$HostEventDto_UpdateImplCopyWithImpl<$Res>;
  @useResult
  $Res call({UpdateDto field0});
}

/// @nodoc
class __$$HostEventDto_UpdateImplCopyWithImpl<$Res>
    extends _$HostEventDtoCopyWithImpl<$Res, _$HostEventDto_UpdateImpl>
    implements _$$HostEventDto_UpdateImplCopyWith<$Res> {
  __$$HostEventDto_UpdateImplCopyWithImpl(
    _$HostEventDto_UpdateImpl _value,
    $Res Function(_$HostEventDto_UpdateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HostEventDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$HostEventDto_UpdateImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as UpdateDto,
      ),
    );
  }
}

/// @nodoc

class _$HostEventDto_UpdateImpl extends HostEventDto_Update {
  const _$HostEventDto_UpdateImpl(this.field0) : super._();

  @override
  final UpdateDto field0;

  @override
  String toString() {
    return 'HostEventDto.update(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HostEventDto_UpdateImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of HostEventDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HostEventDto_UpdateImplCopyWith<_$HostEventDto_UpdateImpl> get copyWith =>
      __$$HostEventDto_UpdateImplCopyWithImpl<_$HostEventDto_UpdateImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<SessionMetaDto> field0) sessions,
    required TResult Function(UpdateDto field0) update,
    required TResult Function(String session, bool running) status,
    required TResult Function(PermissionReqDto field0) permission,
    required TResult Function() disconnected,
  }) {
    return update(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<SessionMetaDto> field0)? sessions,
    TResult? Function(UpdateDto field0)? update,
    TResult? Function(String session, bool running)? status,
    TResult? Function(PermissionReqDto field0)? permission,
    TResult? Function()? disconnected,
  }) {
    return update?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<SessionMetaDto> field0)? sessions,
    TResult Function(UpdateDto field0)? update,
    TResult Function(String session, bool running)? status,
    TResult Function(PermissionReqDto field0)? permission,
    TResult Function()? disconnected,
    required TResult orElse(),
  }) {
    if (update != null) {
      return update(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(HostEventDto_Sessions value) sessions,
    required TResult Function(HostEventDto_Update value) update,
    required TResult Function(HostEventDto_Status value) status,
    required TResult Function(HostEventDto_Permission value) permission,
    required TResult Function(HostEventDto_Disconnected value) disconnected,
  }) {
    return update(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(HostEventDto_Sessions value)? sessions,
    TResult? Function(HostEventDto_Update value)? update,
    TResult? Function(HostEventDto_Status value)? status,
    TResult? Function(HostEventDto_Permission value)? permission,
    TResult? Function(HostEventDto_Disconnected value)? disconnected,
  }) {
    return update?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(HostEventDto_Sessions value)? sessions,
    TResult Function(HostEventDto_Update value)? update,
    TResult Function(HostEventDto_Status value)? status,
    TResult Function(HostEventDto_Permission value)? permission,
    TResult Function(HostEventDto_Disconnected value)? disconnected,
    required TResult orElse(),
  }) {
    if (update != null) {
      return update(this);
    }
    return orElse();
  }
}

abstract class HostEventDto_Update extends HostEventDto {
  const factory HostEventDto_Update(final UpdateDto field0) =
      _$HostEventDto_UpdateImpl;
  const HostEventDto_Update._() : super._();

  UpdateDto get field0;

  /// Create a copy of HostEventDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HostEventDto_UpdateImplCopyWith<_$HostEventDto_UpdateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$HostEventDto_StatusImplCopyWith<$Res> {
  factory _$$HostEventDto_StatusImplCopyWith(
    _$HostEventDto_StatusImpl value,
    $Res Function(_$HostEventDto_StatusImpl) then,
  ) = __$$HostEventDto_StatusImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String session, bool running});
}

/// @nodoc
class __$$HostEventDto_StatusImplCopyWithImpl<$Res>
    extends _$HostEventDtoCopyWithImpl<$Res, _$HostEventDto_StatusImpl>
    implements _$$HostEventDto_StatusImplCopyWith<$Res> {
  __$$HostEventDto_StatusImplCopyWithImpl(
    _$HostEventDto_StatusImpl _value,
    $Res Function(_$HostEventDto_StatusImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HostEventDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? session = null, Object? running = null}) {
    return _then(
      _$HostEventDto_StatusImpl(
        session: null == session
            ? _value.session
            : session // ignore: cast_nullable_to_non_nullable
                  as String,
        running: null == running
            ? _value.running
            : running // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$HostEventDto_StatusImpl extends HostEventDto_Status {
  const _$HostEventDto_StatusImpl({
    required this.session,
    required this.running,
  }) : super._();

  @override
  final String session;
  @override
  final bool running;

  @override
  String toString() {
    return 'HostEventDto.status(session: $session, running: $running)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HostEventDto_StatusImpl &&
            (identical(other.session, session) || other.session == session) &&
            (identical(other.running, running) || other.running == running));
  }

  @override
  int get hashCode => Object.hash(runtimeType, session, running);

  /// Create a copy of HostEventDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HostEventDto_StatusImplCopyWith<_$HostEventDto_StatusImpl> get copyWith =>
      __$$HostEventDto_StatusImplCopyWithImpl<_$HostEventDto_StatusImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<SessionMetaDto> field0) sessions,
    required TResult Function(UpdateDto field0) update,
    required TResult Function(String session, bool running) status,
    required TResult Function(PermissionReqDto field0) permission,
    required TResult Function() disconnected,
  }) {
    return status(session, running);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<SessionMetaDto> field0)? sessions,
    TResult? Function(UpdateDto field0)? update,
    TResult? Function(String session, bool running)? status,
    TResult? Function(PermissionReqDto field0)? permission,
    TResult? Function()? disconnected,
  }) {
    return status?.call(session, running);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<SessionMetaDto> field0)? sessions,
    TResult Function(UpdateDto field0)? update,
    TResult Function(String session, bool running)? status,
    TResult Function(PermissionReqDto field0)? permission,
    TResult Function()? disconnected,
    required TResult orElse(),
  }) {
    if (status != null) {
      return status(session, running);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(HostEventDto_Sessions value) sessions,
    required TResult Function(HostEventDto_Update value) update,
    required TResult Function(HostEventDto_Status value) status,
    required TResult Function(HostEventDto_Permission value) permission,
    required TResult Function(HostEventDto_Disconnected value) disconnected,
  }) {
    return status(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(HostEventDto_Sessions value)? sessions,
    TResult? Function(HostEventDto_Update value)? update,
    TResult? Function(HostEventDto_Status value)? status,
    TResult? Function(HostEventDto_Permission value)? permission,
    TResult? Function(HostEventDto_Disconnected value)? disconnected,
  }) {
    return status?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(HostEventDto_Sessions value)? sessions,
    TResult Function(HostEventDto_Update value)? update,
    TResult Function(HostEventDto_Status value)? status,
    TResult Function(HostEventDto_Permission value)? permission,
    TResult Function(HostEventDto_Disconnected value)? disconnected,
    required TResult orElse(),
  }) {
    if (status != null) {
      return status(this);
    }
    return orElse();
  }
}

abstract class HostEventDto_Status extends HostEventDto {
  const factory HostEventDto_Status({
    required final String session,
    required final bool running,
  }) = _$HostEventDto_StatusImpl;
  const HostEventDto_Status._() : super._();

  String get session;
  bool get running;

  /// Create a copy of HostEventDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HostEventDto_StatusImplCopyWith<_$HostEventDto_StatusImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$HostEventDto_PermissionImplCopyWith<$Res> {
  factory _$$HostEventDto_PermissionImplCopyWith(
    _$HostEventDto_PermissionImpl value,
    $Res Function(_$HostEventDto_PermissionImpl) then,
  ) = __$$HostEventDto_PermissionImplCopyWithImpl<$Res>;
  @useResult
  $Res call({PermissionReqDto field0});
}

/// @nodoc
class __$$HostEventDto_PermissionImplCopyWithImpl<$Res>
    extends _$HostEventDtoCopyWithImpl<$Res, _$HostEventDto_PermissionImpl>
    implements _$$HostEventDto_PermissionImplCopyWith<$Res> {
  __$$HostEventDto_PermissionImplCopyWithImpl(
    _$HostEventDto_PermissionImpl _value,
    $Res Function(_$HostEventDto_PermissionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HostEventDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$HostEventDto_PermissionImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as PermissionReqDto,
      ),
    );
  }
}

/// @nodoc

class _$HostEventDto_PermissionImpl extends HostEventDto_Permission {
  const _$HostEventDto_PermissionImpl(this.field0) : super._();

  @override
  final PermissionReqDto field0;

  @override
  String toString() {
    return 'HostEventDto.permission(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HostEventDto_PermissionImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of HostEventDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HostEventDto_PermissionImplCopyWith<_$HostEventDto_PermissionImpl>
  get copyWith =>
      __$$HostEventDto_PermissionImplCopyWithImpl<
        _$HostEventDto_PermissionImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<SessionMetaDto> field0) sessions,
    required TResult Function(UpdateDto field0) update,
    required TResult Function(String session, bool running) status,
    required TResult Function(PermissionReqDto field0) permission,
    required TResult Function() disconnected,
  }) {
    return permission(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<SessionMetaDto> field0)? sessions,
    TResult? Function(UpdateDto field0)? update,
    TResult? Function(String session, bool running)? status,
    TResult? Function(PermissionReqDto field0)? permission,
    TResult? Function()? disconnected,
  }) {
    return permission?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<SessionMetaDto> field0)? sessions,
    TResult Function(UpdateDto field0)? update,
    TResult Function(String session, bool running)? status,
    TResult Function(PermissionReqDto field0)? permission,
    TResult Function()? disconnected,
    required TResult orElse(),
  }) {
    if (permission != null) {
      return permission(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(HostEventDto_Sessions value) sessions,
    required TResult Function(HostEventDto_Update value) update,
    required TResult Function(HostEventDto_Status value) status,
    required TResult Function(HostEventDto_Permission value) permission,
    required TResult Function(HostEventDto_Disconnected value) disconnected,
  }) {
    return permission(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(HostEventDto_Sessions value)? sessions,
    TResult? Function(HostEventDto_Update value)? update,
    TResult? Function(HostEventDto_Status value)? status,
    TResult? Function(HostEventDto_Permission value)? permission,
    TResult? Function(HostEventDto_Disconnected value)? disconnected,
  }) {
    return permission?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(HostEventDto_Sessions value)? sessions,
    TResult Function(HostEventDto_Update value)? update,
    TResult Function(HostEventDto_Status value)? status,
    TResult Function(HostEventDto_Permission value)? permission,
    TResult Function(HostEventDto_Disconnected value)? disconnected,
    required TResult orElse(),
  }) {
    if (permission != null) {
      return permission(this);
    }
    return orElse();
  }
}

abstract class HostEventDto_Permission extends HostEventDto {
  const factory HostEventDto_Permission(final PermissionReqDto field0) =
      _$HostEventDto_PermissionImpl;
  const HostEventDto_Permission._() : super._();

  PermissionReqDto get field0;

  /// Create a copy of HostEventDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HostEventDto_PermissionImplCopyWith<_$HostEventDto_PermissionImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$HostEventDto_DisconnectedImplCopyWith<$Res> {
  factory _$$HostEventDto_DisconnectedImplCopyWith(
    _$HostEventDto_DisconnectedImpl value,
    $Res Function(_$HostEventDto_DisconnectedImpl) then,
  ) = __$$HostEventDto_DisconnectedImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$HostEventDto_DisconnectedImplCopyWithImpl<$Res>
    extends _$HostEventDtoCopyWithImpl<$Res, _$HostEventDto_DisconnectedImpl>
    implements _$$HostEventDto_DisconnectedImplCopyWith<$Res> {
  __$$HostEventDto_DisconnectedImplCopyWithImpl(
    _$HostEventDto_DisconnectedImpl _value,
    $Res Function(_$HostEventDto_DisconnectedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HostEventDto
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$HostEventDto_DisconnectedImpl extends HostEventDto_Disconnected {
  const _$HostEventDto_DisconnectedImpl() : super._();

  @override
  String toString() {
    return 'HostEventDto.disconnected()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HostEventDto_DisconnectedImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<SessionMetaDto> field0) sessions,
    required TResult Function(UpdateDto field0) update,
    required TResult Function(String session, bool running) status,
    required TResult Function(PermissionReqDto field0) permission,
    required TResult Function() disconnected,
  }) {
    return disconnected();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<SessionMetaDto> field0)? sessions,
    TResult? Function(UpdateDto field0)? update,
    TResult? Function(String session, bool running)? status,
    TResult? Function(PermissionReqDto field0)? permission,
    TResult? Function()? disconnected,
  }) {
    return disconnected?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<SessionMetaDto> field0)? sessions,
    TResult Function(UpdateDto field0)? update,
    TResult Function(String session, bool running)? status,
    TResult Function(PermissionReqDto field0)? permission,
    TResult Function()? disconnected,
    required TResult orElse(),
  }) {
    if (disconnected != null) {
      return disconnected();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(HostEventDto_Sessions value) sessions,
    required TResult Function(HostEventDto_Update value) update,
    required TResult Function(HostEventDto_Status value) status,
    required TResult Function(HostEventDto_Permission value) permission,
    required TResult Function(HostEventDto_Disconnected value) disconnected,
  }) {
    return disconnected(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(HostEventDto_Sessions value)? sessions,
    TResult? Function(HostEventDto_Update value)? update,
    TResult? Function(HostEventDto_Status value)? status,
    TResult? Function(HostEventDto_Permission value)? permission,
    TResult? Function(HostEventDto_Disconnected value)? disconnected,
  }) {
    return disconnected?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(HostEventDto_Sessions value)? sessions,
    TResult Function(HostEventDto_Update value)? update,
    TResult Function(HostEventDto_Status value)? status,
    TResult Function(HostEventDto_Permission value)? permission,
    TResult Function(HostEventDto_Disconnected value)? disconnected,
    required TResult orElse(),
  }) {
    if (disconnected != null) {
      return disconnected(this);
    }
    return orElse();
  }
}

abstract class HostEventDto_Disconnected extends HostEventDto {
  const factory HostEventDto_Disconnected() = _$HostEventDto_DisconnectedImpl;
  const HostEventDto_Disconnected._() : super._();
}

/// @nodoc
mixin _$PayloadDto {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String text) agentMessage,
    required TResult Function(String text) thought,
    required TResult Function(String text) userMessage,
    required TResult Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )
    toolCall,
    required TResult Function(
      String id,
      String status,
      List<ContentDto> content,
    )
    toolCallUpdate,
    required TResult Function(List<String> entries) plan,
    required TResult Function(BigInt input, BigInt output) usage,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String text)? agentMessage,
    TResult? Function(String text)? thought,
    TResult? Function(String text)? userMessage,
    TResult? Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )?
    toolCall,
    TResult? Function(String id, String status, List<ContentDto> content)?
    toolCallUpdate,
    TResult? Function(List<String> entries)? plan,
    TResult? Function(BigInt input, BigInt output)? usage,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String text)? agentMessage,
    TResult Function(String text)? thought,
    TResult Function(String text)? userMessage,
    TResult Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )?
    toolCall,
    TResult Function(String id, String status, List<ContentDto> content)?
    toolCallUpdate,
    TResult Function(List<String> entries)? plan,
    TResult Function(BigInt input, BigInt output)? usage,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(PayloadDto_AgentMessage value) agentMessage,
    required TResult Function(PayloadDto_Thought value) thought,
    required TResult Function(PayloadDto_UserMessage value) userMessage,
    required TResult Function(PayloadDto_ToolCall value) toolCall,
    required TResult Function(PayloadDto_ToolCallUpdate value) toolCallUpdate,
    required TResult Function(PayloadDto_Plan value) plan,
    required TResult Function(PayloadDto_Usage value) usage,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(PayloadDto_AgentMessage value)? agentMessage,
    TResult? Function(PayloadDto_Thought value)? thought,
    TResult? Function(PayloadDto_UserMessage value)? userMessage,
    TResult? Function(PayloadDto_ToolCall value)? toolCall,
    TResult? Function(PayloadDto_ToolCallUpdate value)? toolCallUpdate,
    TResult? Function(PayloadDto_Plan value)? plan,
    TResult? Function(PayloadDto_Usage value)? usage,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(PayloadDto_AgentMessage value)? agentMessage,
    TResult Function(PayloadDto_Thought value)? thought,
    TResult Function(PayloadDto_UserMessage value)? userMessage,
    TResult Function(PayloadDto_ToolCall value)? toolCall,
    TResult Function(PayloadDto_ToolCallUpdate value)? toolCallUpdate,
    TResult Function(PayloadDto_Plan value)? plan,
    TResult Function(PayloadDto_Usage value)? usage,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PayloadDtoCopyWith<$Res> {
  factory $PayloadDtoCopyWith(
    PayloadDto value,
    $Res Function(PayloadDto) then,
  ) = _$PayloadDtoCopyWithImpl<$Res, PayloadDto>;
}

/// @nodoc
class _$PayloadDtoCopyWithImpl<$Res, $Val extends PayloadDto>
    implements $PayloadDtoCopyWith<$Res> {
  _$PayloadDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$PayloadDto_AgentMessageImplCopyWith<$Res> {
  factory _$$PayloadDto_AgentMessageImplCopyWith(
    _$PayloadDto_AgentMessageImpl value,
    $Res Function(_$PayloadDto_AgentMessageImpl) then,
  ) = __$$PayloadDto_AgentMessageImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String text});
}

/// @nodoc
class __$$PayloadDto_AgentMessageImplCopyWithImpl<$Res>
    extends _$PayloadDtoCopyWithImpl<$Res, _$PayloadDto_AgentMessageImpl>
    implements _$$PayloadDto_AgentMessageImplCopyWith<$Res> {
  __$$PayloadDto_AgentMessageImplCopyWithImpl(
    _$PayloadDto_AgentMessageImpl _value,
    $Res Function(_$PayloadDto_AgentMessageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? text = null}) {
    return _then(
      _$PayloadDto_AgentMessageImpl(
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$PayloadDto_AgentMessageImpl extends PayloadDto_AgentMessage {
  const _$PayloadDto_AgentMessageImpl({required this.text}) : super._();

  @override
  final String text;

  @override
  String toString() {
    return 'PayloadDto.agentMessage(text: $text)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PayloadDto_AgentMessageImpl &&
            (identical(other.text, text) || other.text == text));
  }

  @override
  int get hashCode => Object.hash(runtimeType, text);

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PayloadDto_AgentMessageImplCopyWith<_$PayloadDto_AgentMessageImpl>
  get copyWith =>
      __$$PayloadDto_AgentMessageImplCopyWithImpl<
        _$PayloadDto_AgentMessageImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String text) agentMessage,
    required TResult Function(String text) thought,
    required TResult Function(String text) userMessage,
    required TResult Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )
    toolCall,
    required TResult Function(
      String id,
      String status,
      List<ContentDto> content,
    )
    toolCallUpdate,
    required TResult Function(List<String> entries) plan,
    required TResult Function(BigInt input, BigInt output) usage,
  }) {
    return agentMessage(text);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String text)? agentMessage,
    TResult? Function(String text)? thought,
    TResult? Function(String text)? userMessage,
    TResult? Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )?
    toolCall,
    TResult? Function(String id, String status, List<ContentDto> content)?
    toolCallUpdate,
    TResult? Function(List<String> entries)? plan,
    TResult? Function(BigInt input, BigInt output)? usage,
  }) {
    return agentMessage?.call(text);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String text)? agentMessage,
    TResult Function(String text)? thought,
    TResult Function(String text)? userMessage,
    TResult Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )?
    toolCall,
    TResult Function(String id, String status, List<ContentDto> content)?
    toolCallUpdate,
    TResult Function(List<String> entries)? plan,
    TResult Function(BigInt input, BigInt output)? usage,
    required TResult orElse(),
  }) {
    if (agentMessage != null) {
      return agentMessage(text);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(PayloadDto_AgentMessage value) agentMessage,
    required TResult Function(PayloadDto_Thought value) thought,
    required TResult Function(PayloadDto_UserMessage value) userMessage,
    required TResult Function(PayloadDto_ToolCall value) toolCall,
    required TResult Function(PayloadDto_ToolCallUpdate value) toolCallUpdate,
    required TResult Function(PayloadDto_Plan value) plan,
    required TResult Function(PayloadDto_Usage value) usage,
  }) {
    return agentMessage(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(PayloadDto_AgentMessage value)? agentMessage,
    TResult? Function(PayloadDto_Thought value)? thought,
    TResult? Function(PayloadDto_UserMessage value)? userMessage,
    TResult? Function(PayloadDto_ToolCall value)? toolCall,
    TResult? Function(PayloadDto_ToolCallUpdate value)? toolCallUpdate,
    TResult? Function(PayloadDto_Plan value)? plan,
    TResult? Function(PayloadDto_Usage value)? usage,
  }) {
    return agentMessage?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(PayloadDto_AgentMessage value)? agentMessage,
    TResult Function(PayloadDto_Thought value)? thought,
    TResult Function(PayloadDto_UserMessage value)? userMessage,
    TResult Function(PayloadDto_ToolCall value)? toolCall,
    TResult Function(PayloadDto_ToolCallUpdate value)? toolCallUpdate,
    TResult Function(PayloadDto_Plan value)? plan,
    TResult Function(PayloadDto_Usage value)? usage,
    required TResult orElse(),
  }) {
    if (agentMessage != null) {
      return agentMessage(this);
    }
    return orElse();
  }
}

abstract class PayloadDto_AgentMessage extends PayloadDto {
  const factory PayloadDto_AgentMessage({required final String text}) =
      _$PayloadDto_AgentMessageImpl;
  const PayloadDto_AgentMessage._() : super._();

  String get text;

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PayloadDto_AgentMessageImplCopyWith<_$PayloadDto_AgentMessageImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PayloadDto_ThoughtImplCopyWith<$Res> {
  factory _$$PayloadDto_ThoughtImplCopyWith(
    _$PayloadDto_ThoughtImpl value,
    $Res Function(_$PayloadDto_ThoughtImpl) then,
  ) = __$$PayloadDto_ThoughtImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String text});
}

/// @nodoc
class __$$PayloadDto_ThoughtImplCopyWithImpl<$Res>
    extends _$PayloadDtoCopyWithImpl<$Res, _$PayloadDto_ThoughtImpl>
    implements _$$PayloadDto_ThoughtImplCopyWith<$Res> {
  __$$PayloadDto_ThoughtImplCopyWithImpl(
    _$PayloadDto_ThoughtImpl _value,
    $Res Function(_$PayloadDto_ThoughtImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? text = null}) {
    return _then(
      _$PayloadDto_ThoughtImpl(
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$PayloadDto_ThoughtImpl extends PayloadDto_Thought {
  const _$PayloadDto_ThoughtImpl({required this.text}) : super._();

  @override
  final String text;

  @override
  String toString() {
    return 'PayloadDto.thought(text: $text)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PayloadDto_ThoughtImpl &&
            (identical(other.text, text) || other.text == text));
  }

  @override
  int get hashCode => Object.hash(runtimeType, text);

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PayloadDto_ThoughtImplCopyWith<_$PayloadDto_ThoughtImpl> get copyWith =>
      __$$PayloadDto_ThoughtImplCopyWithImpl<_$PayloadDto_ThoughtImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String text) agentMessage,
    required TResult Function(String text) thought,
    required TResult Function(String text) userMessage,
    required TResult Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )
    toolCall,
    required TResult Function(
      String id,
      String status,
      List<ContentDto> content,
    )
    toolCallUpdate,
    required TResult Function(List<String> entries) plan,
    required TResult Function(BigInt input, BigInt output) usage,
  }) {
    return thought(text);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String text)? agentMessage,
    TResult? Function(String text)? thought,
    TResult? Function(String text)? userMessage,
    TResult? Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )?
    toolCall,
    TResult? Function(String id, String status, List<ContentDto> content)?
    toolCallUpdate,
    TResult? Function(List<String> entries)? plan,
    TResult? Function(BigInt input, BigInt output)? usage,
  }) {
    return thought?.call(text);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String text)? agentMessage,
    TResult Function(String text)? thought,
    TResult Function(String text)? userMessage,
    TResult Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )?
    toolCall,
    TResult Function(String id, String status, List<ContentDto> content)?
    toolCallUpdate,
    TResult Function(List<String> entries)? plan,
    TResult Function(BigInt input, BigInt output)? usage,
    required TResult orElse(),
  }) {
    if (thought != null) {
      return thought(text);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(PayloadDto_AgentMessage value) agentMessage,
    required TResult Function(PayloadDto_Thought value) thought,
    required TResult Function(PayloadDto_UserMessage value) userMessage,
    required TResult Function(PayloadDto_ToolCall value) toolCall,
    required TResult Function(PayloadDto_ToolCallUpdate value) toolCallUpdate,
    required TResult Function(PayloadDto_Plan value) plan,
    required TResult Function(PayloadDto_Usage value) usage,
  }) {
    return thought(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(PayloadDto_AgentMessage value)? agentMessage,
    TResult? Function(PayloadDto_Thought value)? thought,
    TResult? Function(PayloadDto_UserMessage value)? userMessage,
    TResult? Function(PayloadDto_ToolCall value)? toolCall,
    TResult? Function(PayloadDto_ToolCallUpdate value)? toolCallUpdate,
    TResult? Function(PayloadDto_Plan value)? plan,
    TResult? Function(PayloadDto_Usage value)? usage,
  }) {
    return thought?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(PayloadDto_AgentMessage value)? agentMessage,
    TResult Function(PayloadDto_Thought value)? thought,
    TResult Function(PayloadDto_UserMessage value)? userMessage,
    TResult Function(PayloadDto_ToolCall value)? toolCall,
    TResult Function(PayloadDto_ToolCallUpdate value)? toolCallUpdate,
    TResult Function(PayloadDto_Plan value)? plan,
    TResult Function(PayloadDto_Usage value)? usage,
    required TResult orElse(),
  }) {
    if (thought != null) {
      return thought(this);
    }
    return orElse();
  }
}

abstract class PayloadDto_Thought extends PayloadDto {
  const factory PayloadDto_Thought({required final String text}) =
      _$PayloadDto_ThoughtImpl;
  const PayloadDto_Thought._() : super._();

  String get text;

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PayloadDto_ThoughtImplCopyWith<_$PayloadDto_ThoughtImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PayloadDto_UserMessageImplCopyWith<$Res> {
  factory _$$PayloadDto_UserMessageImplCopyWith(
    _$PayloadDto_UserMessageImpl value,
    $Res Function(_$PayloadDto_UserMessageImpl) then,
  ) = __$$PayloadDto_UserMessageImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String text});
}

/// @nodoc
class __$$PayloadDto_UserMessageImplCopyWithImpl<$Res>
    extends _$PayloadDtoCopyWithImpl<$Res, _$PayloadDto_UserMessageImpl>
    implements _$$PayloadDto_UserMessageImplCopyWith<$Res> {
  __$$PayloadDto_UserMessageImplCopyWithImpl(
    _$PayloadDto_UserMessageImpl _value,
    $Res Function(_$PayloadDto_UserMessageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? text = null}) {
    return _then(
      _$PayloadDto_UserMessageImpl(
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$PayloadDto_UserMessageImpl extends PayloadDto_UserMessage {
  const _$PayloadDto_UserMessageImpl({required this.text}) : super._();

  @override
  final String text;

  @override
  String toString() {
    return 'PayloadDto.userMessage(text: $text)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PayloadDto_UserMessageImpl &&
            (identical(other.text, text) || other.text == text));
  }

  @override
  int get hashCode => Object.hash(runtimeType, text);

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PayloadDto_UserMessageImplCopyWith<_$PayloadDto_UserMessageImpl>
  get copyWith =>
      __$$PayloadDto_UserMessageImplCopyWithImpl<_$PayloadDto_UserMessageImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String text) agentMessage,
    required TResult Function(String text) thought,
    required TResult Function(String text) userMessage,
    required TResult Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )
    toolCall,
    required TResult Function(
      String id,
      String status,
      List<ContentDto> content,
    )
    toolCallUpdate,
    required TResult Function(List<String> entries) plan,
    required TResult Function(BigInt input, BigInt output) usage,
  }) {
    return userMessage(text);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String text)? agentMessage,
    TResult? Function(String text)? thought,
    TResult? Function(String text)? userMessage,
    TResult? Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )?
    toolCall,
    TResult? Function(String id, String status, List<ContentDto> content)?
    toolCallUpdate,
    TResult? Function(List<String> entries)? plan,
    TResult? Function(BigInt input, BigInt output)? usage,
  }) {
    return userMessage?.call(text);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String text)? agentMessage,
    TResult Function(String text)? thought,
    TResult Function(String text)? userMessage,
    TResult Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )?
    toolCall,
    TResult Function(String id, String status, List<ContentDto> content)?
    toolCallUpdate,
    TResult Function(List<String> entries)? plan,
    TResult Function(BigInt input, BigInt output)? usage,
    required TResult orElse(),
  }) {
    if (userMessage != null) {
      return userMessage(text);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(PayloadDto_AgentMessage value) agentMessage,
    required TResult Function(PayloadDto_Thought value) thought,
    required TResult Function(PayloadDto_UserMessage value) userMessage,
    required TResult Function(PayloadDto_ToolCall value) toolCall,
    required TResult Function(PayloadDto_ToolCallUpdate value) toolCallUpdate,
    required TResult Function(PayloadDto_Plan value) plan,
    required TResult Function(PayloadDto_Usage value) usage,
  }) {
    return userMessage(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(PayloadDto_AgentMessage value)? agentMessage,
    TResult? Function(PayloadDto_Thought value)? thought,
    TResult? Function(PayloadDto_UserMessage value)? userMessage,
    TResult? Function(PayloadDto_ToolCall value)? toolCall,
    TResult? Function(PayloadDto_ToolCallUpdate value)? toolCallUpdate,
    TResult? Function(PayloadDto_Plan value)? plan,
    TResult? Function(PayloadDto_Usage value)? usage,
  }) {
    return userMessage?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(PayloadDto_AgentMessage value)? agentMessage,
    TResult Function(PayloadDto_Thought value)? thought,
    TResult Function(PayloadDto_UserMessage value)? userMessage,
    TResult Function(PayloadDto_ToolCall value)? toolCall,
    TResult Function(PayloadDto_ToolCallUpdate value)? toolCallUpdate,
    TResult Function(PayloadDto_Plan value)? plan,
    TResult Function(PayloadDto_Usage value)? usage,
    required TResult orElse(),
  }) {
    if (userMessage != null) {
      return userMessage(this);
    }
    return orElse();
  }
}

abstract class PayloadDto_UserMessage extends PayloadDto {
  const factory PayloadDto_UserMessage({required final String text}) =
      _$PayloadDto_UserMessageImpl;
  const PayloadDto_UserMessage._() : super._();

  String get text;

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PayloadDto_UserMessageImplCopyWith<_$PayloadDto_UserMessageImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PayloadDto_ToolCallImplCopyWith<$Res> {
  factory _$$PayloadDto_ToolCallImplCopyWith(
    _$PayloadDto_ToolCallImpl value,
    $Res Function(_$PayloadDto_ToolCallImpl) then,
  ) = __$$PayloadDto_ToolCallImplCopyWithImpl<$Res>;
  @useResult
  $Res call({
    String id,
    String kind,
    String title,
    String? command,
    String status,
    List<ContentDto> content,
    List<String> locations,
  });
}

/// @nodoc
class __$$PayloadDto_ToolCallImplCopyWithImpl<$Res>
    extends _$PayloadDtoCopyWithImpl<$Res, _$PayloadDto_ToolCallImpl>
    implements _$$PayloadDto_ToolCallImplCopyWith<$Res> {
  __$$PayloadDto_ToolCallImplCopyWithImpl(
    _$PayloadDto_ToolCallImpl _value,
    $Res Function(_$PayloadDto_ToolCallImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? kind = null,
    Object? title = null,
    Object? command = freezed,
    Object? status = null,
    Object? content = null,
    Object? locations = null,
  }) {
    return _then(
      _$PayloadDto_ToolCallImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        kind: null == kind
            ? _value.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        command: freezed == command
            ? _value.command
            : command // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        content: null == content
            ? _value._content
            : content // ignore: cast_nullable_to_non_nullable
                  as List<ContentDto>,
        locations: null == locations
            ? _value._locations
            : locations // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc

class _$PayloadDto_ToolCallImpl extends PayloadDto_ToolCall {
  const _$PayloadDto_ToolCallImpl({
    required this.id,
    required this.kind,
    required this.title,
    this.command,
    required this.status,
    required final List<ContentDto> content,
    required final List<String> locations,
  }) : _content = content,
       _locations = locations,
       super._();

  @override
  final String id;
  @override
  final String kind;
  @override
  final String title;
  @override
  final String? command;
  @override
  final String status;
  final List<ContentDto> _content;
  @override
  List<ContentDto> get content {
    if (_content is EqualUnmodifiableListView) return _content;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_content);
  }

  final List<String> _locations;
  @override
  List<String> get locations {
    if (_locations is EqualUnmodifiableListView) return _locations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_locations);
  }

  @override
  String toString() {
    return 'PayloadDto.toolCall(id: $id, kind: $kind, title: $title, command: $command, status: $status, content: $content, locations: $locations)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PayloadDto_ToolCallImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.command, command) || other.command == command) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._content, _content) &&
            const DeepCollectionEquality().equals(
              other._locations,
              _locations,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    kind,
    title,
    command,
    status,
    const DeepCollectionEquality().hash(_content),
    const DeepCollectionEquality().hash(_locations),
  );

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PayloadDto_ToolCallImplCopyWith<_$PayloadDto_ToolCallImpl> get copyWith =>
      __$$PayloadDto_ToolCallImplCopyWithImpl<_$PayloadDto_ToolCallImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String text) agentMessage,
    required TResult Function(String text) thought,
    required TResult Function(String text) userMessage,
    required TResult Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )
    toolCall,
    required TResult Function(
      String id,
      String status,
      List<ContentDto> content,
    )
    toolCallUpdate,
    required TResult Function(List<String> entries) plan,
    required TResult Function(BigInt input, BigInt output) usage,
  }) {
    return toolCall(id, kind, title, command, status, content, locations);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String text)? agentMessage,
    TResult? Function(String text)? thought,
    TResult? Function(String text)? userMessage,
    TResult? Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )?
    toolCall,
    TResult? Function(String id, String status, List<ContentDto> content)?
    toolCallUpdate,
    TResult? Function(List<String> entries)? plan,
    TResult? Function(BigInt input, BigInt output)? usage,
  }) {
    return toolCall?.call(id, kind, title, command, status, content, locations);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String text)? agentMessage,
    TResult Function(String text)? thought,
    TResult Function(String text)? userMessage,
    TResult Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )?
    toolCall,
    TResult Function(String id, String status, List<ContentDto> content)?
    toolCallUpdate,
    TResult Function(List<String> entries)? plan,
    TResult Function(BigInt input, BigInt output)? usage,
    required TResult orElse(),
  }) {
    if (toolCall != null) {
      return toolCall(id, kind, title, command, status, content, locations);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(PayloadDto_AgentMessage value) agentMessage,
    required TResult Function(PayloadDto_Thought value) thought,
    required TResult Function(PayloadDto_UserMessage value) userMessage,
    required TResult Function(PayloadDto_ToolCall value) toolCall,
    required TResult Function(PayloadDto_ToolCallUpdate value) toolCallUpdate,
    required TResult Function(PayloadDto_Plan value) plan,
    required TResult Function(PayloadDto_Usage value) usage,
  }) {
    return toolCall(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(PayloadDto_AgentMessage value)? agentMessage,
    TResult? Function(PayloadDto_Thought value)? thought,
    TResult? Function(PayloadDto_UserMessage value)? userMessage,
    TResult? Function(PayloadDto_ToolCall value)? toolCall,
    TResult? Function(PayloadDto_ToolCallUpdate value)? toolCallUpdate,
    TResult? Function(PayloadDto_Plan value)? plan,
    TResult? Function(PayloadDto_Usage value)? usage,
  }) {
    return toolCall?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(PayloadDto_AgentMessage value)? agentMessage,
    TResult Function(PayloadDto_Thought value)? thought,
    TResult Function(PayloadDto_UserMessage value)? userMessage,
    TResult Function(PayloadDto_ToolCall value)? toolCall,
    TResult Function(PayloadDto_ToolCallUpdate value)? toolCallUpdate,
    TResult Function(PayloadDto_Plan value)? plan,
    TResult Function(PayloadDto_Usage value)? usage,
    required TResult orElse(),
  }) {
    if (toolCall != null) {
      return toolCall(this);
    }
    return orElse();
  }
}

abstract class PayloadDto_ToolCall extends PayloadDto {
  const factory PayloadDto_ToolCall({
    required final String id,
    required final String kind,
    required final String title,
    final String? command,
    required final String status,
    required final List<ContentDto> content,
    required final List<String> locations,
  }) = _$PayloadDto_ToolCallImpl;
  const PayloadDto_ToolCall._() : super._();

  String get id;
  String get kind;
  String get title;
  String? get command;
  String get status;
  List<ContentDto> get content;
  List<String> get locations;

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PayloadDto_ToolCallImplCopyWith<_$PayloadDto_ToolCallImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PayloadDto_ToolCallUpdateImplCopyWith<$Res> {
  factory _$$PayloadDto_ToolCallUpdateImplCopyWith(
    _$PayloadDto_ToolCallUpdateImpl value,
    $Res Function(_$PayloadDto_ToolCallUpdateImpl) then,
  ) = __$$PayloadDto_ToolCallUpdateImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String id, String status, List<ContentDto> content});
}

/// @nodoc
class __$$PayloadDto_ToolCallUpdateImplCopyWithImpl<$Res>
    extends _$PayloadDtoCopyWithImpl<$Res, _$PayloadDto_ToolCallUpdateImpl>
    implements _$$PayloadDto_ToolCallUpdateImplCopyWith<$Res> {
  __$$PayloadDto_ToolCallUpdateImplCopyWithImpl(
    _$PayloadDto_ToolCallUpdateImpl _value,
    $Res Function(_$PayloadDto_ToolCallUpdateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? status = null,
    Object? content = null,
  }) {
    return _then(
      _$PayloadDto_ToolCallUpdateImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        content: null == content
            ? _value._content
            : content // ignore: cast_nullable_to_non_nullable
                  as List<ContentDto>,
      ),
    );
  }
}

/// @nodoc

class _$PayloadDto_ToolCallUpdateImpl extends PayloadDto_ToolCallUpdate {
  const _$PayloadDto_ToolCallUpdateImpl({
    required this.id,
    required this.status,
    required final List<ContentDto> content,
  }) : _content = content,
       super._();

  @override
  final String id;
  @override
  final String status;
  final List<ContentDto> _content;
  @override
  List<ContentDto> get content {
    if (_content is EqualUnmodifiableListView) return _content;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_content);
  }

  @override
  String toString() {
    return 'PayloadDto.toolCallUpdate(id: $id, status: $status, content: $content)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PayloadDto_ToolCallUpdateImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._content, _content));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    status,
    const DeepCollectionEquality().hash(_content),
  );

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PayloadDto_ToolCallUpdateImplCopyWith<_$PayloadDto_ToolCallUpdateImpl>
  get copyWith =>
      __$$PayloadDto_ToolCallUpdateImplCopyWithImpl<
        _$PayloadDto_ToolCallUpdateImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String text) agentMessage,
    required TResult Function(String text) thought,
    required TResult Function(String text) userMessage,
    required TResult Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )
    toolCall,
    required TResult Function(
      String id,
      String status,
      List<ContentDto> content,
    )
    toolCallUpdate,
    required TResult Function(List<String> entries) plan,
    required TResult Function(BigInt input, BigInt output) usage,
  }) {
    return toolCallUpdate(id, status, content);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String text)? agentMessage,
    TResult? Function(String text)? thought,
    TResult? Function(String text)? userMessage,
    TResult? Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )?
    toolCall,
    TResult? Function(String id, String status, List<ContentDto> content)?
    toolCallUpdate,
    TResult? Function(List<String> entries)? plan,
    TResult? Function(BigInt input, BigInt output)? usage,
  }) {
    return toolCallUpdate?.call(id, status, content);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String text)? agentMessage,
    TResult Function(String text)? thought,
    TResult Function(String text)? userMessage,
    TResult Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )?
    toolCall,
    TResult Function(String id, String status, List<ContentDto> content)?
    toolCallUpdate,
    TResult Function(List<String> entries)? plan,
    TResult Function(BigInt input, BigInt output)? usage,
    required TResult orElse(),
  }) {
    if (toolCallUpdate != null) {
      return toolCallUpdate(id, status, content);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(PayloadDto_AgentMessage value) agentMessage,
    required TResult Function(PayloadDto_Thought value) thought,
    required TResult Function(PayloadDto_UserMessage value) userMessage,
    required TResult Function(PayloadDto_ToolCall value) toolCall,
    required TResult Function(PayloadDto_ToolCallUpdate value) toolCallUpdate,
    required TResult Function(PayloadDto_Plan value) plan,
    required TResult Function(PayloadDto_Usage value) usage,
  }) {
    return toolCallUpdate(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(PayloadDto_AgentMessage value)? agentMessage,
    TResult? Function(PayloadDto_Thought value)? thought,
    TResult? Function(PayloadDto_UserMessage value)? userMessage,
    TResult? Function(PayloadDto_ToolCall value)? toolCall,
    TResult? Function(PayloadDto_ToolCallUpdate value)? toolCallUpdate,
    TResult? Function(PayloadDto_Plan value)? plan,
    TResult? Function(PayloadDto_Usage value)? usage,
  }) {
    return toolCallUpdate?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(PayloadDto_AgentMessage value)? agentMessage,
    TResult Function(PayloadDto_Thought value)? thought,
    TResult Function(PayloadDto_UserMessage value)? userMessage,
    TResult Function(PayloadDto_ToolCall value)? toolCall,
    TResult Function(PayloadDto_ToolCallUpdate value)? toolCallUpdate,
    TResult Function(PayloadDto_Plan value)? plan,
    TResult Function(PayloadDto_Usage value)? usage,
    required TResult orElse(),
  }) {
    if (toolCallUpdate != null) {
      return toolCallUpdate(this);
    }
    return orElse();
  }
}

abstract class PayloadDto_ToolCallUpdate extends PayloadDto {
  const factory PayloadDto_ToolCallUpdate({
    required final String id,
    required final String status,
    required final List<ContentDto> content,
  }) = _$PayloadDto_ToolCallUpdateImpl;
  const PayloadDto_ToolCallUpdate._() : super._();

  String get id;
  String get status;
  List<ContentDto> get content;

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PayloadDto_ToolCallUpdateImplCopyWith<_$PayloadDto_ToolCallUpdateImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PayloadDto_PlanImplCopyWith<$Res> {
  factory _$$PayloadDto_PlanImplCopyWith(
    _$PayloadDto_PlanImpl value,
    $Res Function(_$PayloadDto_PlanImpl) then,
  ) = __$$PayloadDto_PlanImplCopyWithImpl<$Res>;
  @useResult
  $Res call({List<String> entries});
}

/// @nodoc
class __$$PayloadDto_PlanImplCopyWithImpl<$Res>
    extends _$PayloadDtoCopyWithImpl<$Res, _$PayloadDto_PlanImpl>
    implements _$$PayloadDto_PlanImplCopyWith<$Res> {
  __$$PayloadDto_PlanImplCopyWithImpl(
    _$PayloadDto_PlanImpl _value,
    $Res Function(_$PayloadDto_PlanImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? entries = null}) {
    return _then(
      _$PayloadDto_PlanImpl(
        entries: null == entries
            ? _value._entries
            : entries // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc

class _$PayloadDto_PlanImpl extends PayloadDto_Plan {
  const _$PayloadDto_PlanImpl({required final List<String> entries})
    : _entries = entries,
      super._();

  final List<String> _entries;
  @override
  List<String> get entries {
    if (_entries is EqualUnmodifiableListView) return _entries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_entries);
  }

  @override
  String toString() {
    return 'PayloadDto.plan(entries: $entries)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PayloadDto_PlanImpl &&
            const DeepCollectionEquality().equals(other._entries, _entries));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_entries));

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PayloadDto_PlanImplCopyWith<_$PayloadDto_PlanImpl> get copyWith =>
      __$$PayloadDto_PlanImplCopyWithImpl<_$PayloadDto_PlanImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String text) agentMessage,
    required TResult Function(String text) thought,
    required TResult Function(String text) userMessage,
    required TResult Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )
    toolCall,
    required TResult Function(
      String id,
      String status,
      List<ContentDto> content,
    )
    toolCallUpdate,
    required TResult Function(List<String> entries) plan,
    required TResult Function(BigInt input, BigInt output) usage,
  }) {
    return plan(entries);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String text)? agentMessage,
    TResult? Function(String text)? thought,
    TResult? Function(String text)? userMessage,
    TResult? Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )?
    toolCall,
    TResult? Function(String id, String status, List<ContentDto> content)?
    toolCallUpdate,
    TResult? Function(List<String> entries)? plan,
    TResult? Function(BigInt input, BigInt output)? usage,
  }) {
    return plan?.call(entries);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String text)? agentMessage,
    TResult Function(String text)? thought,
    TResult Function(String text)? userMessage,
    TResult Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )?
    toolCall,
    TResult Function(String id, String status, List<ContentDto> content)?
    toolCallUpdate,
    TResult Function(List<String> entries)? plan,
    TResult Function(BigInt input, BigInt output)? usage,
    required TResult orElse(),
  }) {
    if (plan != null) {
      return plan(entries);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(PayloadDto_AgentMessage value) agentMessage,
    required TResult Function(PayloadDto_Thought value) thought,
    required TResult Function(PayloadDto_UserMessage value) userMessage,
    required TResult Function(PayloadDto_ToolCall value) toolCall,
    required TResult Function(PayloadDto_ToolCallUpdate value) toolCallUpdate,
    required TResult Function(PayloadDto_Plan value) plan,
    required TResult Function(PayloadDto_Usage value) usage,
  }) {
    return plan(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(PayloadDto_AgentMessage value)? agentMessage,
    TResult? Function(PayloadDto_Thought value)? thought,
    TResult? Function(PayloadDto_UserMessage value)? userMessage,
    TResult? Function(PayloadDto_ToolCall value)? toolCall,
    TResult? Function(PayloadDto_ToolCallUpdate value)? toolCallUpdate,
    TResult? Function(PayloadDto_Plan value)? plan,
    TResult? Function(PayloadDto_Usage value)? usage,
  }) {
    return plan?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(PayloadDto_AgentMessage value)? agentMessage,
    TResult Function(PayloadDto_Thought value)? thought,
    TResult Function(PayloadDto_UserMessage value)? userMessage,
    TResult Function(PayloadDto_ToolCall value)? toolCall,
    TResult Function(PayloadDto_ToolCallUpdate value)? toolCallUpdate,
    TResult Function(PayloadDto_Plan value)? plan,
    TResult Function(PayloadDto_Usage value)? usage,
    required TResult orElse(),
  }) {
    if (plan != null) {
      return plan(this);
    }
    return orElse();
  }
}

abstract class PayloadDto_Plan extends PayloadDto {
  const factory PayloadDto_Plan({required final List<String> entries}) =
      _$PayloadDto_PlanImpl;
  const PayloadDto_Plan._() : super._();

  List<String> get entries;

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PayloadDto_PlanImplCopyWith<_$PayloadDto_PlanImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PayloadDto_UsageImplCopyWith<$Res> {
  factory _$$PayloadDto_UsageImplCopyWith(
    _$PayloadDto_UsageImpl value,
    $Res Function(_$PayloadDto_UsageImpl) then,
  ) = __$$PayloadDto_UsageImplCopyWithImpl<$Res>;
  @useResult
  $Res call({BigInt input, BigInt output});
}

/// @nodoc
class __$$PayloadDto_UsageImplCopyWithImpl<$Res>
    extends _$PayloadDtoCopyWithImpl<$Res, _$PayloadDto_UsageImpl>
    implements _$$PayloadDto_UsageImplCopyWith<$Res> {
  __$$PayloadDto_UsageImplCopyWithImpl(
    _$PayloadDto_UsageImpl _value,
    $Res Function(_$PayloadDto_UsageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? input = null, Object? output = null}) {
    return _then(
      _$PayloadDto_UsageImpl(
        input: null == input
            ? _value.input
            : input // ignore: cast_nullable_to_non_nullable
                  as BigInt,
        output: null == output
            ? _value.output
            : output // ignore: cast_nullable_to_non_nullable
                  as BigInt,
      ),
    );
  }
}

/// @nodoc

class _$PayloadDto_UsageImpl extends PayloadDto_Usage {
  const _$PayloadDto_UsageImpl({required this.input, required this.output})
    : super._();

  @override
  final BigInt input;
  @override
  final BigInt output;

  @override
  String toString() {
    return 'PayloadDto.usage(input: $input, output: $output)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PayloadDto_UsageImpl &&
            (identical(other.input, input) || other.input == input) &&
            (identical(other.output, output) || other.output == output));
  }

  @override
  int get hashCode => Object.hash(runtimeType, input, output);

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PayloadDto_UsageImplCopyWith<_$PayloadDto_UsageImpl> get copyWith =>
      __$$PayloadDto_UsageImplCopyWithImpl<_$PayloadDto_UsageImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String text) agentMessage,
    required TResult Function(String text) thought,
    required TResult Function(String text) userMessage,
    required TResult Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )
    toolCall,
    required TResult Function(
      String id,
      String status,
      List<ContentDto> content,
    )
    toolCallUpdate,
    required TResult Function(List<String> entries) plan,
    required TResult Function(BigInt input, BigInt output) usage,
  }) {
    return usage(input, output);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String text)? agentMessage,
    TResult? Function(String text)? thought,
    TResult? Function(String text)? userMessage,
    TResult? Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )?
    toolCall,
    TResult? Function(String id, String status, List<ContentDto> content)?
    toolCallUpdate,
    TResult? Function(List<String> entries)? plan,
    TResult? Function(BigInt input, BigInt output)? usage,
  }) {
    return usage?.call(input, output);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String text)? agentMessage,
    TResult Function(String text)? thought,
    TResult Function(String text)? userMessage,
    TResult Function(
      String id,
      String kind,
      String title,
      String? command,
      String status,
      List<ContentDto> content,
      List<String> locations,
    )?
    toolCall,
    TResult Function(String id, String status, List<ContentDto> content)?
    toolCallUpdate,
    TResult Function(List<String> entries)? plan,
    TResult Function(BigInt input, BigInt output)? usage,
    required TResult orElse(),
  }) {
    if (usage != null) {
      return usage(input, output);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(PayloadDto_AgentMessage value) agentMessage,
    required TResult Function(PayloadDto_Thought value) thought,
    required TResult Function(PayloadDto_UserMessage value) userMessage,
    required TResult Function(PayloadDto_ToolCall value) toolCall,
    required TResult Function(PayloadDto_ToolCallUpdate value) toolCallUpdate,
    required TResult Function(PayloadDto_Plan value) plan,
    required TResult Function(PayloadDto_Usage value) usage,
  }) {
    return usage(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(PayloadDto_AgentMessage value)? agentMessage,
    TResult? Function(PayloadDto_Thought value)? thought,
    TResult? Function(PayloadDto_UserMessage value)? userMessage,
    TResult? Function(PayloadDto_ToolCall value)? toolCall,
    TResult? Function(PayloadDto_ToolCallUpdate value)? toolCallUpdate,
    TResult? Function(PayloadDto_Plan value)? plan,
    TResult? Function(PayloadDto_Usage value)? usage,
  }) {
    return usage?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(PayloadDto_AgentMessage value)? agentMessage,
    TResult Function(PayloadDto_Thought value)? thought,
    TResult Function(PayloadDto_UserMessage value)? userMessage,
    TResult Function(PayloadDto_ToolCall value)? toolCall,
    TResult Function(PayloadDto_ToolCallUpdate value)? toolCallUpdate,
    TResult Function(PayloadDto_Plan value)? plan,
    TResult Function(PayloadDto_Usage value)? usage,
    required TResult orElse(),
  }) {
    if (usage != null) {
      return usage(this);
    }
    return orElse();
  }
}

abstract class PayloadDto_Usage extends PayloadDto {
  const factory PayloadDto_Usage({
    required final BigInt input,
    required final BigInt output,
  }) = _$PayloadDto_UsageImpl;
  const PayloadDto_Usage._() : super._();

  BigInt get input;
  BigInt get output;

  /// Create a copy of PayloadDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PayloadDto_UsageImplCopyWith<_$PayloadDto_UsageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
