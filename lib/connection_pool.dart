library connection_pool;

import 'dart:async';
import 'dart:collection';

part 'package:connection_pool/src/strategies.dart';

/**
 * A generic connection pool 
 * 
 * To create a connection pool, just inherit from this class
 * and provide the [openNewConnection] and [closeConnection] methods.
 */
abstract class ConnectionPool<T> {
  _Strategy _strategy;

  /**
   * Create a new connection pool.
   *
   * [poolSize] is the number of connections that will be managed by
   * this pool. If [shareableConnections] is true (the default value),
   * then the pool will assume that the connections can handle concurrent
   * requests.
   */
  ConnectionPool(int poolSize, {bool shareableConnections: true}) {
    if (shareableConnections) {
      _strategy = new _ShareableConnectionsStrategy(poolSize);
    } else {
      _strategy = new _ExclusiveConnectionsStrategy(poolSize);
    }
  }

  /**
   * Create and open a new connection
   */
  Future<T> openNewConnection();

  /**
   * Close a connection
   */
  void closeConnection(T conn);

  /**
   * Retrieve a connection from the pool
   */
  Future<ManagedConnection<T>> getConnection() {
    return _strategy.getConnection(
        () => openNewConnection().then((conn) => _wrapConn(conn)));
  }

  /**
   * Return a connection to the pool
   */
  void releaseConnection(ManagedConnection conn, {bool markAsInvalid: false}) =>
      _strategy.releaseConnection(closeConnection, conn, markAsInvalid);

  /**
   * Close all opened connections from the pool
   */
  Future closeConnections() => _strategy.closeConnections(closeConnection);
}

class ManagedConnection<T> {
  final int connId;
  final T conn;

  ManagedConnection(this.connId, this.conn);
}

class ConnectionPoolException implements Exception {
  String message;
  dynamic cause;

  ConnectionPoolException([this.message = "", this.cause]);

  String toString() => "ConnectionPoolException: $message Cause: $cause";
}
