part of connection_pool;

typedef Future<ManagedConnection> _ConnCreator();

typedef void _ConnDestroyer(dynamic conn);

abstract class _Strategy {
  Future<ManagedConnection> getConnection(_ConnCreator connCreator);

  void releaseConnection(
      _ConnDestroyer connDestroyer, ManagedConnection conn, bool markAsInvalid);

  Future closeConnections(_ConnDestroyer connDestroyer);
}

class _ShareableConnectionsStrategy implements _Strategy {
  final int _poolSize;
  List<Future<ManagedConnection>> _pool;
  int _pointer = 0;
  final Map<int, int> _connMap = {};

  _ShareableConnectionsStrategy(this._poolSize) {
    _pool = new List(_poolSize);
  }

  Future<ManagedConnection> getConnection(_ConnCreator connCreator) {
    int idx = _pointer++ % _poolSize;
    var conn = _pool[idx];
    if (conn != null) {
      return conn;
    }
    var completer = new Completer();
    _pool[idx] = completer.future;
    connCreator().then((conn) {
      _connMap[conn.connId] = idx;
      completer.complete(conn);
    }).catchError((e) {
      var ex = new ConnectionPoolException("Failed to open connection.", e);
      completer.completeError(ex);
      _pool[idx] = null;
    });
    return completer.future;
  }

  void releaseConnection(_ConnDestroyer connDestroyer, ManagedConnection conn,
      bool markAsInvalid) {
    if (markAsInvalid) {
      int idx = _connMap[conn.connId];
      if (idx != null) {
        _pool[idx] = null;
        _connMap.remove(conn.connId);
      }
      connDestroyer(conn.conn);
    }
  }

  Future closeConnections(_ConnDestroyer connDestroyer) async {
    for (var futureConn in _pool) {
      if (futureConn != null) {
        var conn = await futureConn;
        releaseConnection(connDestroyer, conn, true);
      }
    }
  }
}

class _ExclusiveConnectionsStrategy implements _Strategy {
  final int _poolSize;
  List<_LockableConn> _pool;
  Queue<Completer> _callbacks = new Queue();
  final Map<int, int> _connMap = {};

  _ExclusiveConnectionsStrategy(this._poolSize) {
    _pool = new List(_poolSize);
  }

  Future<ManagedConnection> getConnection(_ConnCreator connCreator) {
    for (var i = 0; i < _poolSize; i++) {
      var connLock = _pool[i];
      if (connLock == null) {
        var completer = new Completer();
        connCreator().then((conn) {
          _connMap[conn.connId] = i;
          completer.complete(conn);
        }).catchError((e) {
          var ex = new ConnectionPoolException("Failed to open connection.", e);
          completer.completeError(ex);
          _pool[i] = null;
        });
        _pool[i] = new _LockableConn(completer.future, true);
        return completer.future;
      } else if (!connLock.locked) {
        connLock.locked = true;
        return connLock.conn;
      }
    }

    var completer = new Completer();
    _callbacks.add(completer);
    return completer.future;
  }

  void releaseConnection(_ConnDestroyer connDestroyer, ManagedConnection conn,
      bool markAsInvalid) {
    if (!markAsInvalid) {
      if (_callbacks.isNotEmpty) {
        _callbacks.removeFirst().complete(conn);
      } else {
        int id = _connMap[conn.connId];
        if (id != null) {
          var lockableConn = _pool[id];
          if (lockableConn != null) {
            lockableConn.locked = false;
          }
        }
      }
    } else {
      int id = _connMap[conn.connId];
      if (id != null) {
        _pool[id] = null;
        _connMap.remove(conn.connId);
      }
      connDestroyer(conn.conn);
    }
  }

  Future closeConnections(_ConnDestroyer connDestroyer) async {
    for (var lockableConn in _pool) {
      if (lockableConn.conn != null) {
        var conn = await lockableConn.conn;
        releaseConnection(connDestroyer, conn, true);
      }
    }
  }
}

class _LockableConn {
  Future<ManagedConnection> conn;
  bool locked;

  _LockableConn(this.conn, this.locked);
}

int _nextId = 0;

ManagedConnection _wrapConn(dynamic conn) =>
    new ManagedConnection(_nextId++, conn);
