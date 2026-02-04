module Tests exposing (suite)

import Expect
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "WebUI Test Suite"
        [ describe "Placeholder Tests"
            [ test "Example test passes" <|
                \_ ->
                    Expect.pass
            ]
        ]
