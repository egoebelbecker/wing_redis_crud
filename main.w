bring cloud;
bring ex;
bring http;
bring expect;

struct Entry {
  id: str;
  name: str;
  contents: str;
}

interface IEntryStorage extends std.IResource {
  inflight add(name: str, contents: str): str;
  inflight update(id: str, name: str, contents: str): str;
  inflight remove(id: str): void;
  inflight get(id: str): Entry?;
}

class EntryStorage impl IEntryStorage {
  db: ex.Redis;
  counter: cloud.Counter;

  new() {
    this.db = new ex.Redis();
    this.counter = new cloud.Counter();
  }

  inflight _add(id: str, j: Json) {
    this.db.set(id , Json.stringify(j));
  }

  pub inflight add(name: str, contents: str): str {
    let id = "{this.counter.inc()}";
    let entryJson = {
      id: id,
      name: name,
      contents: contents
    };
    this._add(id, entryJson);
    log("adding entry {id} with data: {entryJson}");
    return id;
  }

  pub inflight update(id: str, name: str, contents: str): str {
    let entryJson = {
      id: id,
      name: name,
      contents: contents
    };
    this._add(id, entryJson);
    log("adding entry {id} with data: {entryJson}");
    return id;
  }

  pub inflight remove(id: str) {
    this.db.del(id);
    log("removing entry {id}");
  }

  pub inflight get(id: str): Entry? {
    if let entryJson = this.db.get(id) {
      return Entry.fromJson(Json.parse(entryJson));
    }
  }
}

class EntryService {
  pub api: cloud.Api;
  entryStorage: IEntryStorage;


  new(storage: IEntryStorage) {
    this.api = new cloud.Api(cors: true);
    this.entryStorage = storage;

    // API endpoints
    this.api.post("/entries", inflight (req): cloud.ApiResponse => {
      if let body = req.body {

        try {
          let var name = Json.parse(body).get("name").asStr();
          let var contents = Json.parse(body).get("contents").asStr();
          let id = this.entryStorage.add(name, contents);
          return {
            status:201,
            body: id
          };


        } catch e {
          return {
            status: 500
          };
        }

      } else {
        return {
          status: 400,
        };
      }
    });

    this.api.put("/entries/:id", inflight (req): cloud.ApiResponse => {
      if let body = req.body {
        let id = req.vars.get("id");
        let var contents = Json.parse(body).get("contents").asStr();
        let var name = Json.parse(body).get("name").asStr();

        let new_id = this.entryStorage.update(id, name, contents);
        return {
          status:201,
          body: new_id
        };
      } else {
        return {
          status: 400,
        };
      }
    });

    this.api.get("/entries/:id", inflight (req): cloud.ApiResponse => {
      let id = req.vars.get("id");
      try {
        if let entryJson = this.entryStorage.get(id) {
          return {
            status:200,
            body: "{Json entryJson}"
          };
        }
        else {
          return {
            status:404,
          };
        }
      } catch {
        return {
          status: 400
        };
      }
    });

    this.api.delete("/entries/:id", inflight (req): cloud.ApiResponse => {
      let id = req.vars.get("id");
      try {
        this.entryStorage.remove(id);
        return {
          status: 204 };
      } catch {
        return {
          status: 400
        };
      }
    });
  }
}

let storage = new EntryStorage();
let entryApi = new EntryService(storage);

test "Add and Retrieve Entry" {

    let headers = {
        "Content-Type": "application/json"
    };

    let bodyJson = Json {
      name: "en",
      contents: "this is content"
    };

    log(Json.stringify(bodyJson));
    // Get our base URL
    let url = entryApi.api.url;
    
    // Now use it
    let post_response = http.post("{url}/entries", {
        headers: headers,
        body: Json.stringify(bodyJson)
    });
  

    expect.equal(post_response.status, 201);

    let id = post_response.body;

  // Now use it
  let get_response = http.get("{url}/entries/{id}", {
    headers: headers
  });

  expect.equal(get_response.status, 200); 
  expect.equal(Json.parse(get_response.body).get("name").asStr(), "en");
  expect.equal(Json.parse(get_response.body).get("contents").asStr(), "this is content");

}
