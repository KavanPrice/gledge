import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result

import handler.{
  type Config, type ConnectionResult, type Handler, Connected, ConnectionFailed,
  Unauthorized,
}

// TODO: Implement FFI for this
pub type MqttClient

pub type Status {
  Down
  Ready
  Up
  Conn
  Auth
  ConfError
  AddrError
}

pub type DriverMessage(state, spec) {
  // Internal messages
  MqttConnected
  MqttMessage(topic: String, payload: BitArray)

  // Configuration messages from Edge Agent
  ActiveMessage(payload: BitArray)
  ConfMessage(payload: BitArray)
  AddrMessage(payload: BitArray)
  CmdMessage(command_name: String, data: BitArray)

  // Handler lifecycle
  ConnectHandler
  ReconnectHandler
  UpdateSelf(Subject(DriverMessage(state, spec)))

  // Public API for handlers to send data
  PublishData(topic: String, value: Dynamic)
}

pub type DriverState(handler_state, spec) {
  DriverState(
    id: String,
    mqtt: MqttClient,
    handler: Option(Handler(handler_state, spec)),
    handler_state: Option(handler_state),
    status: Status,
    addrs: Option(Dict(String, spec)),
    topics: Option(Dict(spec, String)),
    reconnect_delay: Int,
    reconnecting: Bool,
    self: Option(Subject(DriverMessage(handler_state, spec))),
  )
}

pub type DriverConfig(handler_state, spec) {
  DriverConfig(
    edge_mqtt: String,
    edge_username: String,
    edge_password: String,
    handler: Handler(handler_state, spec),
  )
}

// Create and start the driver actor
pub fn start(
  config: DriverConfig(handler_state, spec),
) -> Result(Subject(DriverMessage(handler_state, spec)), actor.StartError) {
  // TODO: create MQTT client (via FFI to Erlang MQTT library)
  let mqtt = create_mqtt_client(config)

  let initial_state =
    DriverState(
      id: config.edge_username,
      mqtt: mqtt,
      handler: Some(config.handler),
      handler_state: None,
      status: Down,
      addrs: None,
      topics: None,
      reconnect_delay: 5000,
      reconnecting: False,
      self: None,
    )

  use started <- result.map(
    actor.new(initial_state)
    |> actor.on_message(handle_message)
    |> actor.start,
  )

  let subject = started.data

  // Store self reference in state
  process.send(subject, UpdateSelf(subject))

  subject
}

fn handle_message(
  state: DriverState(handler_state, spec),
  message: DriverMessage(handler_state, spec),
) -> actor.Next(
  DriverState(handler_state, spec),
  DriverMessage(handler_state, spec),
) {
  case message {
    UpdateSelf(subject) -> {
      let new_state = DriverState(..state, self: Some(subject))
      actor.continue(new_state)
    }

    MqttConnected -> {
      // Subscribe to Edge Agent topics
      let topics = [
        topic(state.id, "active", None),
        topic(state.id, "conf", None),
        topic(state.id, "addr", None),
        topic(state.id, "cmd/#", None),
      ]
      subscribe_mqtt(state.mqtt, topics)

      let new_state = set_status(state, Ready)
      actor.continue(new_state)
    }

    MqttMessage(mqtt_topic, payload) -> {
      // Parse topic to determine message type
      case parse_topic(mqtt_topic) {
        Ok(#("active", None)) -> handle_active_message(state, payload)
        Ok(#("conf", None)) -> handle_conf_message(state, payload)
        Ok(#("addr", None)) -> handle_addr_message(state, payload)
        Ok(#("cmd", Some(command_name))) ->
          handle_cmd_message(state, command_name, payload)
        _ -> actor.continue(state)
      }
    }

    ActiveMessage(payload) -> {
      handle_active_message(state, payload)
    }

    ConfMessage(payload) -> {
      handle_conf_message(state, payload)
    }

    AddrMessage(payload) -> {
      handle_addr_message(state, payload)
    }

    CmdMessage(command_name, data) -> {
      handle_cmd_message(state, command_name, data)
    }

    ConnectHandler -> {
      connect_handler(state)
    }

    ReconnectHandler -> {
      case state.reconnecting, state.self {
        True, _ -> actor.continue(state)
        False, Some(self) -> {
          // Wait for reconnect_delay, then connect
          process.send_after(self, state.reconnect_delay, ConnectHandler)
          actor.continue(DriverState(..state, reconnecting: True))
        }
        False, None -> actor.continue(state)
      }
    }

    PublishData(data_topic, value) -> {
      // Convert value to JSON and publish
      // This would be called by handler implementations
      publish_mqtt(state.mqtt, data_topic, value)
      actor.continue(state)
    }
  }
}

fn handle_active_message(
  state: DriverState(handler_state, spec),
  payload: BitArray,
) -> actor.Next(
  DriverState(handler_state, spec),
  DriverMessage(handler_state, spec),
) {
  case payload {
    <<"ONLINE":utf8>> -> {
      let new_state = set_status(state, Ready)
      actor.continue(new_state)
    }
    _ -> actor.continue(state)
  }
}

fn handle_conf_message(
  state: DriverState(handler_state, spec),
  payload: BitArray,
) -> actor.Next(
  DriverState(handler_state, spec),
  DriverMessage(handler_state, spec),
) {
  // Parse JSON configuration
  case parse_json_config(payload) {
    Error(_) -> {
      let new_state = set_status(state, ConfError)
      actor.continue(new_state)
    }
    Ok(config) -> {
      // Clear addresses
      let state = DriverState(..state, addrs: None, topics: None)

      // Close old handler if it exists
      case state.handler_state, state.handler {
        Some(old_state), Some(handler) -> {
          handler.close(old_state)
        }
        _, _ -> Nil
      }

      // Create new handler
      case state.handler {
        Some(handler) -> {
          case handler.create(config) {
            Ok(new_handler_state) -> {
              let new_state =
                DriverState(..state, handler_state: Some(new_handler_state))
              // Connect the handler
              case state.self {
                Some(self) -> process.send(self, ConnectHandler)
                None -> Nil
              }
              actor.continue(new_state)
            }
            Error(_) -> {
              let new_state = set_status(state, ConfError)
              actor.continue(new_state)
            }
          }
        }
        None -> {
          let new_state = set_status(state, ConfError)
          actor.continue(new_state)
        }
      }
    }
  }
}

fn handle_addr_message(
  state: DriverState(handler_state, spec),
  payload: BitArray,
) -> actor.Next(
  DriverState(handler_state, spec),
  DriverMessage(handler_state, spec),
) {
  case state.handler, state.handler_state {
    Some(handler), Some(_) -> {
      case parse_json_addrs(payload) {
        Error(_) -> {
          let new_state = set_status(state, AddrError)
          actor.continue(new_state)
        }
        Ok(addrs_dict) -> {
          // Parse all addresses using handler.parse_addr
          case parse_all_addrs(handler, addrs_dict) {
            Error(_) -> {
              let new_state = set_status(state, AddrError)
              actor.continue(new_state)
            }
            Ok(parsed_addrs) -> {
              let topics_map =
                dict.fold(parsed_addrs, dict.new(), fn(acc, topic_id, spec) {
                  dict.insert(acc, spec, topic_id)
                })

              let new_state =
                DriverState(
                  ..state,
                  addrs: Some(parsed_addrs),
                  topics: Some(topics_map),
                )

              try_subscribe(new_state)
            }
          }
        }
      }
    }
    _, _ -> {
      io.println("Received addrs without handler")
      actor.continue(state)
    }
  }
}

fn handle_cmd_message(
  state: DriverState(handler_state, spec),
  command_name: String,
  data: BitArray,
) -> actor.Next(
  DriverState(handler_state, spec),
  DriverMessage(handler_state, spec),
) {
  case state.handler, state.handler_state {
    Some(handler), Some(hstate) -> {
      case handler.handle_cmd(hstate, command_name, data) {
        Ok(new_hstate) ->
          actor.continue(DriverState(..state, handler_state: Some(new_hstate)))
        Error(_) -> actor.continue(state)
      }
    }
    _, _ -> actor.continue(state)
  }
}

fn connect_handler(
  state: DriverState(handler_state, spec),
) -> actor.Next(
  DriverState(handler_state, spec),
  DriverMessage(handler_state, spec),
) {
  case state.handler, state.handler_state, state.self {
    Some(handler), Some(hstate), Some(self) -> {
      case handler.connect(hstate) {
        Ok(Connected) -> {
          let new_state = set_status(state, Up)
          try_subscribe(new_state)
        }
        Ok(ConnectionFailed) -> {
          let new_state = set_status(state, Conn)
          process.send(self, ReconnectHandler)
          actor.continue(new_state)
        }
        Ok(Unauthorized) -> {
          let new_state = set_status(state, Auth)
          process.send(self, ReconnectHandler)
          actor.continue(new_state)
        }
        Error(_) -> {
          let new_state = set_status(state, Conn)
          process.send(self, ReconnectHandler)
          actor.continue(new_state)
        }
      }
    }
    _, _, _ -> actor.continue(state)
  }
}

fn try_subscribe(
  state: DriverState(handler_state, spec),
) -> actor.Next(
  DriverState(handler_state, spec),
  DriverMessage(handler_state, spec),
) {
  case
    state.handler,
    state.handler_state,
    state.status,
    state.addrs,
    state.self
  {
    Some(handler), Some(hstate), Up, Some(addrs), Some(self) -> {
      let specs = dict.values(addrs)
      case handler.subscribe(hstate, specs) {
        Ok(new_hstate) -> {
          actor.continue(DriverState(..state, handler_state: Some(new_hstate)))
        }
        Error(_) -> {
          let new_state = set_status(state, Conn)
          process.send(self, ReconnectHandler)
          actor.continue(new_state)
        }
      }
    }
    _, _, _, _, _ -> {
      // Not ready to subscribe yet
      actor.continue(state)
    }
  }
}

fn parse_all_addrs(
  handler: Handler(handler_state, spec),
  addrs: Dict(String, String),
) -> Result(Dict(String, spec), Nil) {
  dict.fold(addrs, Ok(dict.new()), fn(acc, topic_id, addr_string) {
    use parsed_dict <- result.try(acc)
    use parsed_spec <- result.try(
      handler.parse_addr(addr_string) |> result.replace_error(Nil),
    )
    Ok(dict.insert(parsed_dict, topic_id, parsed_spec))
  })
}

fn set_status(
  state: DriverState(handler_state, spec),
  status: Status,
) -> DriverState(handler_state, spec) {
  let status_string = status_to_string(status)
  publish_mqtt_status(
    state.mqtt,
    topic(state.id, "status", None),
    status_string,
  )
  DriverState(..state, status: status)
}

fn status_to_string(status: Status) -> String {
  case status {
    Down -> "DOWN"
    Ready -> "READY"
    Up -> "UP"
    Conn -> "CONN"
    Auth -> "AUTH"
    ConfError -> "CONF"
    AddrError -> "ADDR"
  }
}

fn topic(id: String, msg: String, data: Option(String)) -> String {
  case data {
    Some(d) -> "fpEdge1/" <> id <> "/" <> msg <> "/" <> d
    None -> "fpEdge1/" <> id <> "/" <> msg
  }
}

fn parse_topic(mqtt_topic: String) -> Result(#(String, Option(String)), Nil) {
  // Parse "fpEdge1/{id}/{msg}" or "fpEdge1/{id}/{msg}/{data}"
  // This is a simplified version
  todo as "Implement topic parsing"
}

// TODO: implement FFI for these functions
@external(erlang, "driver_ffi", "create_mqtt_client")
fn create_mqtt_client(config: DriverConfig(handler_state, spec)) -> MqttClient

@external(erlang, "driver_ffi", "subscribe_mqtt")
fn subscribe_mqtt(client: MqttClient, topics: List(String)) -> Nil

@external(erlang, "driver_ffi", "publish_mqtt")
fn publish_mqtt(client: MqttClient, topic: String, value: Dynamic) -> Nil

@external(erlang, "driver_ffi", "publish_mqtt_status")
fn publish_mqtt_status(client: MqttClient, topic: String, status: String) -> Nil

@external(erlang, "driver_ffi", "parse_json_config")
fn parse_json_config(payload: BitArray) -> Result(Config, Nil)

@external(erlang, "driver_ffi", "parse_json_addrs")
fn parse_json_addrs(payload: BitArray) -> Result(Dict(String, String), Nil)
