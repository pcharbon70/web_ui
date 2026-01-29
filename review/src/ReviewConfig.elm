module ReviewConfig exposing (config)

{-| Review configuration for WebUI Elm project.

Run elm-review from the project root:
    elm-review

-}

import Review.Rule as Rule exposing (Rule)


config : List Rule
config =
    [ Rule.noUnusedCustomTypeConstructorArgs
    , Rule.noUnusedImports
    , Rule.noUnusedVariables
    , Rule.noMissingTypeAnnotationInLetIn
    , Rule.noMissingTypeAnnotationInTopLevelBindings
    , Rule.noMissingTypeAliasExpose
    , Rule.noUnusedPatternAliases
    ]
        |> List.map (Rule.withIgnores [])
