**Unfortunatelly, I won't be able to maintain this project (and any other open-source project) in the foreseeable future. I'm terrible sorry for this, and if you are relying on this code base for your project(s), please, accept my apologies.** 

**Also, if you have the interest, feel free to fork this repository and improve it. (for Redstone, you'll probably want to take a look at the v0.6 branch, which has a nicer code base).**

**For all you guys who have helped me improving this project, my sincere thanks.**

connection_pool
===============

[![Build Status](https://drone.io/github.com/luizmineo/connection_pool/status.png)](https://drone.io/github.com/luizmineo/connection_pool/latest)

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
