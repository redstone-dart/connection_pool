
import 'dart:async';

import 'package:unittest/unittest.dart';

import 'package:connection_pool/connection_pool.dart';

int nextId = 0;

class Conn {
  
  int id = nextId++;
  String state = "active";
  
}

class ConnPool extends ConnectionPool<Conn> {
  
  ConnPool(int size, bool shareableConn) : 
    super(size, shareableConnections: shareableConn);
  
  @override
  void closeConnection(Conn conn) {
    conn.state = "closed";
  }

  @override
  Future<Conn> openNewConnection() {
    return new Future.value(new Conn());
  }
}

main() {
  
  setUp(() => nextId = 0);
  
  test("Pool w/ shareable connections", () {
    var size = 3;
    var pool = new ConnPool(size, true);
    var fConns = [];
    var conns = null;
    
    for (var i = 0; i < size * 2; i++) {
      fConns.add(pool.getConnection());
    }
    
    return Future.wait(fConns).then((List<ManagedConnection<Conn>> _conns) {
      conns = _conns;
      int id = 0;
      conns.forEach((conn) {
        expect(conn.conn.id, equals(id++ % size));
      });
    }).then((_) {
      pool.releaseConnection(conns[0], markAsInvalid: true);
      return pool.getConnection().then((conn) {
        expect(conn.conn.id, equals(size));
      });
    });
  });
  
  test("Pool w/ exclusive connections", () {
    var size = 3;
    var pool = new ConnPool(size, false);
    var fConns = [];
    var conns = null;
    
    for (var i = 0; i < size; i++) {
      fConns.add(pool.getConnection());
    }
    
    return Future.wait(fConns).then((List<ManagedConnection<Conn>> _conns) {
      conns = _conns;
      int id = 0;
      conns.forEach((conn) {
        expect(conn.conn.id, equals(id++ % size));
      });
    }).then((_) {
      var newConns = [];
      for (var i = 0; i < size; i++) {
        newConns.add(pool.getConnection());
      }
      
      var actions = [];
      
      var f = Future.forEach(newConns, (fc) {
        return fc.then((c) {
          actions.add("locked ${c.conn.id}");
        });
      });
      
      Future.forEach(conns, (c) {
        return new Future(() {
          actions.add("unlocked ${c.conn.id}");
          pool.releaseConnection(c);
        });
      });
      
      return f.then((_) {
        var expected = [];
        for (var i = 0; i < size; i++) {
          expected.add("unlocked $i");
          expected.add("locked $i");
        }
        expect(actions, equals(expected));
      });
    }).then((_) {
      pool.releaseConnection(conns[0], markAsInvalid: true);
      return pool.getConnection().then((conn) {
        expect(conn.conn.id, equals(size));
      });
    });
  });
}