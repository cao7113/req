defmodule Req.UtilsTest do
  use ExUnit.Case, async: true

  # TODO: Remove when we require Elixir 1.14
  if Version.match?(System.version(), "~> 1.14") do
    doctest Req.Utils
  end

  describe "aws_sigv4_headers" do
    test "GET" do
      options = [
        access_key_id: "dummy-access-key-id",
        secret_access_key: "dummy-secret-access-key",
        region: "dummy-region",
        service: "s3",
        datetime: ~U[2024-01-01 09:00:00Z],
        method: :get,
        url: "https://s3/foo/:bar",
        headers: [{"host", "s3"}],
        body: ""
      ]

      signature1 = Req.Utils.aws_sigv4_headers(options)

      signature2 =
        :aws_signature.sign_v4(
          Keyword.fetch!(options, :access_key_id),
          Keyword.fetch!(options, :secret_access_key),
          Keyword.fetch!(options, :region),
          Keyword.fetch!(options, :service),
          Keyword.fetch!(options, :datetime) |> NaiveDateTime.to_erl(),
          Keyword.fetch!(options, :method) |> Atom.to_string() |> String.upcase(),
          Keyword.fetch!(options, :url),
          Keyword.fetch!(options, :headers),
          Keyword.fetch!(options, :body),
          Keyword.take(options, [:body_digest])
        )

      assert signature1 ==
               Enum.map(signature2, fn {name, value} -> {String.downcase(name), value} end)
    end

    test "custom port" do
      options = [
        access_key_id: "dummy-access-key-id",
        secret_access_key: "dummy-secret-access-key",
        region: "dummy-region",
        service: "s3",
        datetime: ~U[2024-01-01 09:00:00Z],
        method: :get,
        url: "https://s3-compatible.com:4433/foo/:bar",
        headers: [],
        body: ""
      ]

      signature1 = Req.Utils.aws_sigv4_headers(options)

      signature2 =
        Req.Utils.aws_sigv4_headers(
          Keyword.put(options, :headers, [{"host", "s3-compatible.com"}])
        )

      signature3 =
        :aws_signature.sign_v4(
          Keyword.fetch!(options, :access_key_id),
          Keyword.fetch!(options, :secret_access_key),
          Keyword.fetch!(options, :region),
          Keyword.fetch!(options, :service),
          Keyword.fetch!(options, :datetime) |> NaiveDateTime.to_erl(),
          Keyword.fetch!(options, :method) |> Atom.to_string() |> String.upcase(),
          Keyword.fetch!(options, :url),
          [{"host", "s3-compatible.com:4433"}],
          Keyword.fetch!(options, :body),
          Keyword.take(options, [:body_digest])
        )

      assert signature1 === signature2

      assert signature1 ==
               Enum.map(signature3, fn {name, value} -> {String.downcase(name), value} end)

      assert signature2 ==
               Enum.map(signature3, fn {name, value} -> {String.downcase(name), value} end)
    end
  end

  describe "aws_sigv4_url" do
    test "GET" do
      options = [
        access_key_id: "dummy-access-key-id",
        secret_access_key: "dummy-secret-access-key",
        region: "dummy-region",
        service: "s3",
        datetime: ~U[2024-01-01 09:00:00Z],
        method: :get,
        url: "https://s3/foo/:bar"
      ]

      url1 = to_string(Req.Utils.aws_sigv4_url(options))

      url2 =
        """
        https://s3/foo/%3Abar?\
        X-Amz-Algorithm=AWS4-HMAC-SHA256\
        &X-Amz-Credential=dummy-access-key-id%2F20240101%2Fdummy-region%2Fs3%2Faws4_request\
        &X-Amz-Date=20240101T090000Z\
        &X-Amz-Expires=86400\
        &X-Amz-SignedHeaders=host\
        &X-Amz-Signature=7fd16f0749b0902acde5a3d8933315006f2993b279b995cad880165ff4be75ff\
        """

      assert url1 == url2
    end

    test "custom port" do
      options = [
        access_key_id: "dummy-access-key-id",
        secret_access_key: "dummy-secret-access-key",
        region: "dummy-region",
        service: "s3",
        datetime: ~U[2024-01-01 09:00:00Z],
        method: :get,
        url: "https://s3-compatible.com:4433/foo/:bar"
      ]

      url1 = to_string(Req.Utils.aws_sigv4_url(options))

      url2 =
        """
        https://s3-compatible.com:4433/foo/%3Abar?\
        X-Amz-Algorithm=AWS4-HMAC-SHA256\
        &X-Amz-Credential=dummy-access-key-id%2F20240101%2Fdummy-region%2Fs3%2Faws4_request\
        &X-Amz-Date=20240101T090000Z\
        &X-Amz-Expires=86400\
        &X-Amz-SignedHeaders=host\
        &X-Amz-Signature=860c79d524ea488a96b56d9e687348f108262738a5205f907cc0794f73d23403\
        """

      assert url1 == url2
    end

    test "custom headers" do
      options = [
        access_key_id: "dummy-access-key-id",
        secret_access_key: "dummy-secret-access-key",
        region: "dummy-region",
        service: "s3",
        datetime: ~U[2024-01-01 09:00:00Z],
        method: :put,
        url: "https://s3/foo/hello_world.txt",
        headers: [{"content-length", 11}]
      ]

      url1 = to_string(Req.Utils.aws_sigv4_url(options))

      url2 =
        """
        https://s3/foo/hello_world.txt?\
        X-Amz-Algorithm=AWS4-HMAC-SHA256\
        &X-Amz-Credential=dummy-access-key-id%2F20240101%2Fdummy-region%2Fs3%2Faws4_request\
        &X-Amz-Date=20240101T090000Z\
        &X-Amz-Expires=86400\
        &X-Amz-SignedHeaders=content-length%3Bhost\
        &X-Amz-Signature=dbb4ae08836db5089a924f2eb52eb52dbc1c372a384a6a99ceb469b14b83e995\
        """

      assert url1 == url2
    end

    test "custom query" do
      options = [
        access_key_id: "dummy-access-key-id",
        secret_access_key: "dummy-secret-access-key",
        region: "dummy-region",
        service: "s3",
        datetime: ~U[2024-01-01 09:00:00Z],
        method: :get,
        url: "https://s3/foo/hello_world.txt",
        query: [{"response-content-disposition", ~s(attachment; filename="hello_world.txt")}]
      ]

      url1 = to_string(Req.Utils.aws_sigv4_url(options))

      url2 =
        """
        https://s3/foo/hello_world.txt?\
        X-Amz-Algorithm=AWS4-HMAC-SHA256\
        &X-Amz-Credential=dummy-access-key-id%2F20240101%2Fdummy-region%2Fs3%2Faws4_request\
        &X-Amz-Date=20240101T090000Z\
        &X-Amz-Expires=86400\
        &X-Amz-SignedHeaders=host\
        &response-content-disposition=attachment%3B%20filename%3D%22hello_world.txt%22\
        &X-Amz-Signature=574a638441ff0e623c800b7379408748d58f3e6679e3ca2619c5900fa030beed\
        """

      assert url1 == url2
    end
  end

  describe "encode_form_multipart" do
    test "it works" do
      %{content_type: content_type, body: body, size: size} =
        Req.Utils.encode_form_multipart(
          [
            field1: 1,
            field2: {"22", filename: "2.txt"},
            field3: {["3", ?3, ?3], filename: "3.txt", content_type: "text/plain"}
          ],
          boundary: "foo"
        )

      body = IO.iodata_to_binary(body)
      assert size == byte_size(body)
      assert content_type == "multipart/form-data; boundary=foo"

      assert body == """
             --foo\r\n\
             content-disposition: form-data; name=\"field1\"\r\n\
             \r\n\
             1\r\n\
             --foo\r\n\
             content-disposition: form-data; name=\"field2\"; filename=\"2.txt\"\r\n\
             \r\n\
             22\r\n\
             --foo\r\n\
             content-disposition: form-data; name=\"field3\"; filename=\"3.txt\"\r\n\
             content-type: text/plain\r\n\
             \r\n\
             333\r\n\
             --foo--\r\n\
             """
    end

    test "it works with size" do
      %{content_type: content_type, body: body, size: size} =
        Req.Utils.encode_form_multipart([field1: {"value", size: 5}], boundary: "foo")

      body = IO.iodata_to_binary(body)

      assert size == byte_size(body)
      assert content_type == "multipart/form-data; boundary=foo"

      assert body == """
             --foo\r\n\
             content-disposition: form-data; name=\"field1\"\r\n\
             \r\n\
             value\r\n\
             --foo--\r\n\
             """
    end

    test "can accept any enumerable" do
      enum = Stream.cycle(["a"]) |> Stream.take(10)

      %{body: body, size: size} =
        Req.Utils.encode_form_multipart([field1: {enum, size: 10}], boundary: "foo")

      body = body |> Enum.to_list() |> IO.iodata_to_binary()

      assert size == byte_size(body)
    end

    test "blindly trust :content_length option" do
      enum = Stream.cycle(["a"]) |> Stream.take(10)
      advertised_length = 50

      %{body: body, size: size} =
        Req.Utils.encode_form_multipart([field1: {enum, size: advertised_length}],
          boundary: "foo"
        )

      body = body |> Enum.to_list() |> IO.iodata_to_binary()

      assert size ==
               byte_size(body) + advertised_length - IO.iodata_length(enum |> Enum.to_list())
    end

    test "can return nil size" do
      enum = Stream.cycle(["a"]) |> Stream.take(10)

      %{size: size} =
        Req.Utils.encode_form_multipart([field1: {enum, []}],
          boundary: "foo"
        )

      assert size == nil
    end

    @tag :tmp_dir
    test "can return stream", %{tmp_dir: tmp_dir} do
      File.write!("#{tmp_dir}/2.txt", "22")

      %{body: body, size: size} =
        Req.Utils.encode_form_multipart(
          [
            field1: 1,
            field2: File.stream!("#{tmp_dir}/2.txt")
          ],
          boundary: "foo"
        )

      assert is_function(body)
      body = body |> Enum.to_list() |> IO.iodata_to_binary()
      assert size == byte_size(body)

      assert body == """
             --foo\r\n\
             content-disposition: form-data; name=\"field1\"\r\n\
             \r\n\
             1\r\n\
             --foo\r\n\
             content-disposition: form-data; name=\"field2\"; filename=\"2.txt\"\r\n\
             content-type: text/plain\r\n\
             \r\n\
             22\r\n\
             --foo--\r\n\
             """

      %{body: body, size: size} =
        Req.Utils.encode_form_multipart(
          [
            field2: File.stream!("#{tmp_dir}/2.txt"),
            field1: 1
          ],
          boundary: "foo"
        )

      assert is_function(body)
      body = body |> Enum.to_list() |> IO.iodata_to_binary()
      assert size == byte_size(body)

      assert body == """
             --foo\r\n\
             content-disposition: form-data; name=\"field2\"; filename=\"2.txt\"\r\n\
             content-type: text/plain\r\n\
             \r\n\
             22\r\n\
             --foo\r\n\
             content-disposition: form-data; name=\"field1\"\r\n\
             \r\n\
             1\r\n\
             --foo--\r\n\
             """
    end
  end
end
