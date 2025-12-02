import buffer
import gleam/json
import gleeunit
import gleeunit/should

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn buffer_from_int8_test() {
  buffer.from_int8(10)
  |> should.equal(<<0xA>>)

  buffer.from_int8(-1)
  |> should.equal(<<0xFF>>)
}

pub fn buffer_from_uint8_test() {
  buffer.from_uint8(255)
  |> should.equal(<<0xFF>>)
}

pub fn buffer_from_int16_le_test() {
  buffer.from_int16_le(258)
  |> should.equal(<<0x02, 0x01>>)
}

pub fn buffer_from_int16_be_test() {
  buffer.from_int16_be(258)
  |> should.equal(<<0x01, 0x02>>)
}

pub fn buffer_from_uint16_le_test() {
  buffer.from_uint16_le(65_535)
  |> should.equal(<<0xFF, 0xFF>>)
}

pub fn buffer_from_uint16_be_test() {
  buffer.from_uint16_be(65_535)
  |> should.equal(<<0xFF, 0xFF>>)
}

pub fn buffer_from_int32_le_test() {
  buffer.from_int32_le(67_305_985)
  |> should.equal(<<0x01, 0x02, 0x03, 0x04>>)
}

pub fn buffer_from_int32_be_test() {
  buffer.from_int32_be(67_305_985)
  |> should.equal(<<0x04, 0x03, 0x02, 0x01>>)
}

pub fn buffer_from_uint32_le_test() {
  buffer.from_uint32_le(4_294_967_295)
  |> should.equal(<<0xFF, 0xFF, 0xFF, 0xFF>>)
}

pub fn buffer_from_uint32_be_test() {
  buffer.from_uint32_be(4_294_967_295)
  |> should.equal(<<0xFF, 0xFF, 0xFF, 0xFF>>)
}

pub fn buffer_from_int64_le_test() {
  buffer.from_int64_le(0x0102030405060708)
  |> should.equal(<<0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01>>)
}

pub fn buffer_from_int64_be_test() {
  buffer.from_int64_be(0x0102030405060708)
  |> should.equal(<<0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08>>)
}

pub fn buffer_from_uint64_le_test() {
  buffer.from_uint64_le(0x0102030405060708)
  |> should.equal(<<0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01>>)
}

pub fn buffer_from_uint64_be_test() {
  buffer.from_uint64_be(0x0102030405060708)
  |> should.equal(<<0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08>>)
}

pub fn buffer_from_float32_le_test() {
  buffer.from_float32_le(1.0)
  |> should.equal(<<0x00, 0x00, 0x80, 0x3F>>)
}

pub fn buffer_from_float32_be_test() {
  buffer.from_float32_be(1.0)
  |> should.equal(<<0x3F, 0x80, 0x00, 0x00>>)
}

pub fn buffer_from_float64_le_test() {
  buffer.from_float64_le(1.0)
  |> should.equal(<<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x3F>>)
}

pub fn buffer_from_float64_be_test() {
  buffer.from_float64_be(1.0)
  |> should.equal(<<0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>)
}

pub fn buffer_from_json_test() {
  json.object([#("key", json.int(1)), #("value", json.string("test"))])
  |> buffer.from_json
  |> should.equal(<<
    0x7B,
    0x22,
    0x6B,
    0x65,
    0x79,
    0x22,
    0x3A,
    0x31,
    0x2C,
    0x22,
    0x76,
    0x61,
    0x6C,
    0x75,
    0x65,
    0x22,
    0x3A,
    0x22,
    0x74,
    0x65,
    0x73,
    0x74,
    0x22,
    0x7D,
  >>)
}
