// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'resilient_http_client_stub.dart'
    if (dart.library.io) 'resilient_http_client_io.dart'
    as impl;

http.Client createResilientHttpClient() => impl.createResilientHttpClient();

WebSocketChannel connectResilientWebSocket(
  Uri uri, {
  Duration? pingInterval,
  Duration? connectTimeout,
}) => impl.connectResilientWebSocket(
  uri,
  pingInterval: pingInterval,
  connectTimeout: connectTimeout,
);
