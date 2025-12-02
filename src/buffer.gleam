/// A collection of functions for converting standard Gleam types (Int, Float, json.Value)
/// into a BitArray (raw binary data/bytes) with specified size and endianness,
/// similar to Python's struct.pack.
import gleam/bit_array
import gleam/json

pub fn from_int8(value: Int) -> BitArray {
  <<value:size(8)>>
}

pub fn from_uint8(value: Int) -> BitArray {
  <<value:size(8)>>
}

pub fn from_int16_le(value: Int) -> BitArray {
  <<value:size(16)-little>>
}

pub fn from_int16_be(value: Int) -> BitArray {
  <<value:size(16)-big>>
}

pub fn from_uint16_le(value: Int) -> BitArray {
  <<value:size(16)-little>>
}

pub fn from_uint16_be(value: Int) -> BitArray {
  <<value:size(16)-big>>
}

pub fn from_int32_le(value: Int) -> BitArray {
  <<value:size(32)-little>>
}

pub fn from_int32_be(value: Int) -> BitArray {
  <<value:size(32)-big>>
}

pub fn from_uint32_le(value: Int) -> BitArray {
  <<value:size(32)-little>>
}

pub fn from_uint32_be(value: Int) -> BitArray {
  <<value:size(32)-big>>
}

pub fn from_int64_le(value: Int) -> BitArray {
  <<value:size(64)-little>>
}

pub fn from_int64_be(value: Int) -> BitArray {
  <<value:size(64)-big>>
}

pub fn from_uint64_le(value: Int) -> BitArray {
  <<value:size(64)-little>>
}

pub fn from_uint64_be(value: Int) -> BitArray {
  <<value:size(64)-big>>
}

pub fn from_float32_le(value: Float) -> BitArray {
  <<value:size(32)-float-little>>
}

pub fn from_float32_be(value: Float) -> BitArray {
  <<value:size(32)-float-big>>
}

pub fn from_float64_le(value: Float) -> BitArray {
  <<value:size(64)-float-little>>
}

pub fn from_float64_be(value: Float) -> BitArray {
  <<value:size(64)-float-big>>
}

pub fn from_json(value: json.Json) -> BitArray {
  json.to_string(value)
  |> bit_array.from_string
}
