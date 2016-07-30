# Connection Pool

[![Build Status](https://travis-ci.org/redstone-dart/connection_pool.svg?branch=master)](https://travis-ci.org/redstone-dart/connection_pool?branch=master)
[![Pub version](https://img.shields.io/pub/v/connection_pool.svg)](https://pub.dartlang.org/packages/connection_pool)

A very simple generic connection pool.

Example: How to build a MongoDB connection pool, and use it in a [Redstone.dart](http://luizmineo.github.io/redstone.dart) app

```dart
import 'package:redstone/server.dart' as app;
import 'package:connection_pool/connection_pool.dart';
import 'package:mongo_dart/mongo_dart.dart';

/**
 * A MongoDB connection pool
 *
 */
class MongoDbPool extends ConnectionPool<Db> {

  String uri;

  MongoDbPool(String this.uri, int poolSize) : super(poolSize);

  @override
  void closeConnection(Db conn) {
    conn.close();
  }

  @override
  Future<Db> openNewConnection() {
    var conn = new Db(uri);
    return conn.open().then((_) => conn);
  }
}

/**
 * Retrieve and release a connection from the pool.
 */
app.Interceptor(r'/.*')
dbInterceptor(MongoDbPool pool) {

  //get a connection
  pool.getConnection().then((managedConnection) {

    //save the connection in the attributes map
    app.request.attributes["conn"] = managedConnection.conn;

    app.chain.next(() {
      if (app.chain.error is ConnectionException) {
        //if a connection is lost, mark it as invalid, so the pool can reopen it
        //in the next request
        pool.releaseConnection(managedConnection, markAsInvalid: true);
      } else {
        //release the connection
        pool.releaseConnection(managedConnection);
      }
    });

  });
}

//To use a connection, just retrieve it from the attributes map
@app.Route('/service')
service(@app.Attr() Db conn) {
  ...
}


main() {

  app.setupConsoleLog();

  //create a connection pool
  var mongodbUri = "mongodb://localhost/database";
  var poolSize = 3;

  app.addModule(new Module()
    ..bind(MongoDbPool, toValue: new MongoDbPool(mongoDbUri, poolSize)));

  app.start();
}
```
