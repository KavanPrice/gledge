import gleam/dynamic.{type Dynamic}

pub type ConnectionResult {
  Connected
  ConnectionFailed
  Unauthorized
}

pub type HandlerMessage {
  DataReceived(address: String, value: Dynamic)
  ConnectionStatusChanged(ConnectionResult)
  SubscriptionUpdate(List(String))
}

pub type Config

pub type Handler(state, spec) {
  Handler(
    create: fn(Config) -> Result(state, String),
    connect: fn(state) -> Result(ConnectionResult, String),
    parse_addr: fn(String) -> Result(spec, String),
    subscribe: fn(state, List(spec)) -> Result(state, String),
    handle_cmd: fn(state, String, BitArray) -> Result(state, String),
    close: fn(state) -> Nil,
  )
}
