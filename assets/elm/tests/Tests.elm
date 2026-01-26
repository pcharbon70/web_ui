module Tests exposing (suite)

import Test exposing (Test, describe, test)
import Expect


suite : Test
suite =
    describe "WebUI Test Suite"
        [ describe "Placeholder Tests"
            [ test "Example test passes" <| \_ ->
                Expect.pass
            ]
        ]
