module Example exposing (suite)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)


suite : Test
suite =
    describe "Example Tests"
        [ test "Addition works correctly" <|
            \_ ->
                Expect.equal 4 (2 + 2)
        ]
