module OpenSolid.Scene
    exposing
        ( RenderOption
        , devicePixelRatio
        , gammaCorrection
        , render
        , renderWith
        , toEntities
        , toEntitiesWith
        )

import Html exposing (Html)
import Html.Attributes
import Math.Matrix4 exposing (Mat4)
import Math.Vector3 as Vector3 exposing (Vec3)
import OpenSolid.Frame3d as Frame3d
import OpenSolid.Geometry.Types exposing (..)
import OpenSolid.Scene.Light exposing (Light)
import OpenSolid.Scene.Node exposing (Node)
import OpenSolid.Scene.Shader as Shader
import OpenSolid.Scene.Types as Types
import OpenSolid.WebGL.Camera as Camera exposing (Camera)
import OpenSolid.WebGL.Frame3d as Frame3d
import OpenSolid.WebGL.Point3d as Point3d
import WebGL
import WebGL.Settings
import WebGL.Settings.DepthTest


type alias AmbientProperties =
    { color : Vec3
    , lookupTexture : WebGL.Texture
    }


type alias LightProperties =
    { lightType : Int
    , lightColor : Vec3
    , lightVector : Vec3
    , lightRadius : Float
    }


type alias MaterialProperties =
    { baseColor : Vec3
    , roughness : Float
    , metallic : Float
    }


type alias PhysicallyBasedRenderer =
    List WebGL.Settings.Setting
    -> Vec3
    -> Mat4
    -> Mat4
    -> MaterialProperties
    -> Float
    -> WebGL.Mesh { vertexPosition : Vec3, vertexNormal : Vec3 }
    -> WebGL.Entity


type PhysicallyBasedLighting
    = AmbientOnlyLighting AmbientProperties
    | AmbientLighting1 AmbientProperties LightProperties
    | AmbientLighting2 AmbientProperties LightProperties LightProperties
    | AmbientLighting3 AmbientProperties LightProperties LightProperties LightProperties
    | AmbientLighting4 AmbientProperties LightProperties LightProperties LightProperties LightProperties
    | AmbientLighting5 AmbientProperties LightProperties LightProperties LightProperties LightProperties LightProperties
    | AmbientLighting6 AmbientProperties LightProperties LightProperties LightProperties LightProperties LightProperties LightProperties
    | AmbientLighting7 AmbientProperties LightProperties LightProperties LightProperties LightProperties LightProperties LightProperties LightProperties
    | AmbientLighting8 AmbientProperties LightProperties LightProperties LightProperties LightProperties LightProperties LightProperties LightProperties LightProperties
    | NoAmbientLighting1 LightProperties
    | NoAmbientLighting2 LightProperties LightProperties
    | NoAmbientLighting3 LightProperties LightProperties LightProperties
    | NoAmbientLighting4 LightProperties LightProperties LightProperties LightProperties
    | NoAmbientLighting5 LightProperties LightProperties LightProperties LightProperties LightProperties
    | NoAmbientLighting6 LightProperties LightProperties LightProperties LightProperties LightProperties LightProperties
    | NoAmbientLighting7 LightProperties LightProperties LightProperties LightProperties LightProperties LightProperties LightProperties
    | NoAmbientLighting8 LightProperties LightProperties LightProperties LightProperties LightProperties LightProperties LightProperties LightProperties
    | DummyLighting


type alias RenderProperties =
    { cameraFrame : Frame3d
    , eyePoint : Vec3
    , projectionMatrix : Mat4
    , physicallyBasedRenderer : PhysicallyBasedRenderer
    , gammaCorrection : Float
    }


physicallyBasedLighting : List Light -> PhysicallyBasedLighting
physicallyBasedLighting lights =
    let
        updateLightingState light currentState =
            case light of
                Types.AmbientLight ambientLight ->
                    { currentState
                        | ambientLightColor =
                            Vector3.add ambientLight.color
                                currentState.ambientLightColor
                        , ambientLookupTexture = Just ambientLight.lookupTexture
                    }

                Types.DirectionalLight directionalLight ->
                    let
                        thisLight =
                            { lightType = 1
                            , lightColor = directionalLight.color
                            , lightVector = directionalLight.direction
                            , lightRadius = 0
                            }
                    in
                    { currentState
                        | lights = thisLight :: currentState.lights
                    }

                Types.PointLight pointLight ->
                    let
                        thisLight =
                            { lightType = 2
                            , lightColor = pointLight.color
                            , lightVector = pointLight.position
                            , lightRadius = 0
                            }
                    in
                    { currentState
                        | lights = thisLight :: currentState.lights
                    }

        initialLightingState =
            { ambientLightColor = Vector3.vec3 0 0 0
            , ambientLookupTexture = Nothing
            , lights = []
            }

        lightingState =
            List.foldl updateLightingState initialLightingState lights
    in
    case lightingState.ambientLookupTexture of
        Just lookupTexture ->
            let
                ambientProperties =
                    { color = lightingState.ambientLightColor
                    , lookupTexture = lookupTexture
                    }
            in
            case lightingState.lights of
                [] ->
                    AmbientOnlyLighting ambientProperties

                [ light1 ] ->
                    AmbientLighting1 ambientProperties light1

                [ light1, light2 ] ->
                    AmbientLighting2 ambientProperties light1 light2

                [ light1, light2, light3 ] ->
                    AmbientLighting3 ambientProperties light1 light2 light3

                [ light1, light2, light3, light4 ] ->
                    AmbientLighting4 ambientProperties light1 light2 light3 light4

                [ light1, light2, light3, light4, light5 ] ->
                    AmbientLighting5 ambientProperties light1 light2 light3 light4 light5

                [ light1, light2, light3, light4, light5, light6 ] ->
                    AmbientLighting6 ambientProperties light1 light2 light3 light4 light5 light6

                [ light1, light2, light3, light4, light5, light6, light7 ] ->
                    AmbientLighting7 ambientProperties light1 light2 light3 light4 light5 light6 light7

                [ light1, light2, light3, light4, light5, light6, light7, light8 ] ->
                    AmbientLighting8 ambientProperties light1 light2 light3 light4 light5 light6 light7 light8

                _ ->
                    DummyLighting

        Nothing ->
            case lightingState.lights of
                [] ->
                    DummyLighting

                [ light1 ] ->
                    NoAmbientLighting1 light1

                [ light1, light2 ] ->
                    NoAmbientLighting2 light1 light2

                [ light1, light2, light3 ] ->
                    NoAmbientLighting3 light1 light2 light3

                [ light1, light2, light3, light4 ] ->
                    NoAmbientLighting4 light1 light2 light3 light4

                [ light1, light2, light3, light4, light5 ] ->
                    NoAmbientLighting5 light1 light2 light3 light4 light5

                [ light1, light2, light3, light4, light5, light6 ] ->
                    NoAmbientLighting6 light1 light2 light3 light4 light5 light6

                [ light1, light2, light3, light4, light5, light6, light7 ] ->
                    NoAmbientLighting7 light1 light2 light3 light4 light5 light6 light7

                [ light1, light2, light3, light4, light5, light6, light7, light8 ] ->
                    NoAmbientLighting8 light1 light2 light3 light4 light5 light6 light7 light8

                _ ->
                    DummyLighting


physicallyBasedRendererFor : List Light -> PhysicallyBasedRenderer
physicallyBasedRendererFor lights =
    case physicallyBasedLighting lights of
        AmbientOnlyLighting ambientProperties ->
            \settings eyePoint modelMatrix modelViewProjectionMatrix material gammaCorrection mesh ->
                let
                    uniforms =
                        { modelMatrix = modelMatrix
                        , modelViewProjectionMatrix = modelViewProjectionMatrix
                        , eyePoint = eyePoint
                        , baseColor = material.baseColor
                        , roughness = material.roughness
                        , metallic = material.metallic
                        , gammaCorrection = gammaCorrection
                        , ambientLightColor = ambientProperties.color
                        , ambientLookupTexture = ambientProperties.lookupTexture
                        }
                in
                WebGL.entityWith settings Shader.vertex Shader.ambientOnly mesh uniforms

        AmbientLighting1 ambientProperties light1 ->
            \settings eyePoint modelMatrix modelViewProjectionMatrix material gammaCorrection mesh ->
                let
                    uniforms =
                        { modelMatrix = modelMatrix
                        , modelViewProjectionMatrix = modelViewProjectionMatrix
                        , eyePoint = eyePoint
                        , baseColor = material.baseColor
                        , roughness = material.roughness
                        , metallic = material.metallic
                        , gammaCorrection = gammaCorrection
                        , ambientLightColor = ambientProperties.color
                        , ambientLookupTexture = ambientProperties.lookupTexture
                        , lightType1 = light1.lightType
                        , lightColor1 = light1.lightColor
                        , lightVector1 = light1.lightVector
                        , lightRadius1 = light1.lightRadius
                        }
                in
                WebGL.entityWith settings Shader.vertex Shader.ambient1 mesh uniforms

        AmbientLighting2 ambientProperties light1 light2 ->
            \settings eyePoint modelMatrix modelViewProjectionMatrix material gammaCorrection mesh ->
                let
                    uniforms =
                        { modelMatrix = modelMatrix
                        , modelViewProjectionMatrix = modelViewProjectionMatrix
                        , eyePoint = eyePoint
                        , baseColor = material.baseColor
                        , roughness = material.roughness
                        , metallic = material.metallic
                        , gammaCorrection = gammaCorrection
                        , ambientLightColor = ambientProperties.color
                        , ambientLookupTexture = ambientProperties.lookupTexture
                        , lightType1 = light1.lightType
                        , lightColor1 = light1.lightColor
                        , lightVector1 = light1.lightVector
                        , lightRadius1 = light1.lightRadius
                        , lightType2 = light2.lightType
                        , lightColor2 = light2.lightColor
                        , lightVector2 = light2.lightVector
                        , lightRadius2 = light2.lightRadius
                        }
                in
                WebGL.entityWith settings Shader.vertex Shader.ambient2 mesh uniforms

        AmbientLighting3 ambientProperties light1 light2 light3 ->
            \settings eyePoint modelMatrix modelViewProjectionMatrix material gammaCorrection mesh ->
                let
                    uniforms =
                        { modelMatrix = modelMatrix
                        , modelViewProjectionMatrix = modelViewProjectionMatrix
                        , eyePoint = eyePoint
                        , baseColor = material.baseColor
                        , roughness = material.roughness
                        , metallic = material.metallic
                        , gammaCorrection = gammaCorrection
                        , ambientLightColor = ambientProperties.color
                        , ambientLookupTexture = ambientProperties.lookupTexture
                        , lightType1 = light1.lightType
                        , lightColor1 = light1.lightColor
                        , lightVector1 = light1.lightVector
                        , lightRadius1 = light1.lightRadius
                        , lightType2 = light2.lightType
                        , lightColor2 = light2.lightColor
                        , lightVector2 = light2.lightVector
                        , lightRadius2 = light2.lightRadius
                        , lightType3 = light3.lightType
                        , lightColor3 = light3.lightColor
                        , lightVector3 = light3.lightVector
                        , lightRadius3 = light3.lightRadius
                        }
                in
                WebGL.entityWith settings Shader.vertex Shader.ambient3 mesh uniforms

        AmbientLighting4 ambientProperties light1 light2 light3 light4 ->
            \settings eyePoint modelMatrix modelViewProjectionMatrix material gammaCorrection mesh ->
                let
                    uniforms =
                        { modelMatrix = modelMatrix
                        , modelViewProjectionMatrix = modelViewProjectionMatrix
                        , eyePoint = eyePoint
                        , baseColor = material.baseColor
                        , roughness = material.roughness
                        , metallic = material.metallic
                        , gammaCorrection = gammaCorrection
                        , ambientLightColor = ambientProperties.color
                        , ambientLookupTexture = ambientProperties.lookupTexture
                        , lightType1 = light1.lightType
                        , lightColor1 = light1.lightColor
                        , lightVector1 = light1.lightVector
                        , lightRadius1 = light1.lightRadius
                        , lightType2 = light2.lightType
                        , lightColor2 = light2.lightColor
                        , lightVector2 = light2.lightVector
                        , lightRadius2 = light2.lightRadius
                        , lightType3 = light3.lightType
                        , lightColor3 = light3.lightColor
                        , lightVector3 = light3.lightVector
                        , lightRadius3 = light3.lightRadius
                        , lightType4 = light4.lightType
                        , lightColor4 = light4.lightColor
                        , lightVector4 = light4.lightVector
                        , lightRadius4 = light4.lightRadius
                        }
                in
                WebGL.entityWith settings Shader.vertex Shader.ambient4 mesh uniforms

        AmbientLighting5 ambientProperties light1 light2 light3 light4 light5 ->
            \settings eyePoint modelMatrix modelViewProjectionMatrix material gammaCorrection mesh ->
                let
                    uniforms =
                        { modelMatrix = modelMatrix
                        , modelViewProjectionMatrix = modelViewProjectionMatrix
                        , eyePoint = eyePoint
                        , baseColor = material.baseColor
                        , roughness = material.roughness
                        , metallic = material.metallic
                        , gammaCorrection = gammaCorrection
                        , ambientLightColor = ambientProperties.color
                        , ambientLookupTexture = ambientProperties.lookupTexture
                        , lightType1 = light1.lightType
                        , lightColor1 = light1.lightColor
                        , lightVector1 = light1.lightVector
                        , lightRadius1 = light1.lightRadius
                        , lightType2 = light2.lightType
                        , lightColor2 = light2.lightColor
                        , lightVector2 = light2.lightVector
                        , lightRadius2 = light2.lightRadius
                        , lightType3 = light3.lightType
                        , lightColor3 = light3.lightColor
                        , lightVector3 = light3.lightVector
                        , lightRadius3 = light3.lightRadius
                        , lightType4 = light4.lightType
                        , lightColor4 = light4.lightColor
                        , lightVector4 = light4.lightVector
                        , lightRadius4 = light4.lightRadius
                        , lightType5 = light5.lightType
                        , lightColor5 = light5.lightColor
                        , lightVector5 = light5.lightVector
                        , lightRadius5 = light5.lightRadius
                        }
                in
                WebGL.entityWith settings Shader.vertex Shader.ambient5 mesh uniforms

        AmbientLighting6 ambientProperties light1 light2 light3 light4 light5 light6 ->
            \settings eyePoint modelMatrix modelViewProjectionMatrix material gammaCorrection mesh ->
                let
                    uniforms =
                        { modelMatrix = modelMatrix
                        , modelViewProjectionMatrix = modelViewProjectionMatrix
                        , eyePoint = eyePoint
                        , baseColor = material.baseColor
                        , roughness = material.roughness
                        , metallic = material.metallic
                        , gammaCorrection = gammaCorrection
                        , ambientLightColor = ambientProperties.color
                        , ambientLookupTexture = ambientProperties.lookupTexture
                        , lightType1 = light1.lightType
                        , lightColor1 = light1.lightColor
                        , lightVector1 = light1.lightVector
                        , lightRadius1 = light1.lightRadius
                        , lightType2 = light2.lightType
                        , lightColor2 = light2.lightColor
                        , lightVector2 = light2.lightVector
                        , lightRadius2 = light2.lightRadius
                        , lightType3 = light3.lightType
                        , lightColor3 = light3.lightColor
                        , lightVector3 = light3.lightVector
                        , lightRadius3 = light3.lightRadius
                        , lightType4 = light4.lightType
                        , lightColor4 = light4.lightColor
                        , lightVector4 = light4.lightVector
                        , lightRadius4 = light4.lightRadius
                        , lightType5 = light5.lightType
                        , lightColor5 = light5.lightColor
                        , lightVector5 = light5.lightVector
                        , lightRadius5 = light5.lightRadius
                        , lightType6 = light6.lightType
                        , lightColor6 = light6.lightColor
                        , lightVector6 = light6.lightVector
                        , lightRadius6 = light6.lightRadius
                        }
                in
                WebGL.entityWith settings Shader.vertex Shader.ambient6 mesh uniforms

        AmbientLighting7 ambientProperties light1 light2 light3 light4 light5 light6 light7 ->
            \settings eyePoint modelMatrix modelViewProjectionMatrix material gammaCorrection mesh ->
                let
                    uniforms =
                        { modelMatrix = modelMatrix
                        , modelViewProjectionMatrix = modelViewProjectionMatrix
                        , eyePoint = eyePoint
                        , baseColor = material.baseColor
                        , roughness = material.roughness
                        , metallic = material.metallic
                        , gammaCorrection = gammaCorrection
                        , ambientLightColor = ambientProperties.color
                        , ambientLookupTexture = ambientProperties.lookupTexture
                        , lightType1 = light1.lightType
                        , lightColor1 = light1.lightColor
                        , lightVector1 = light1.lightVector
                        , lightRadius1 = light1.lightRadius
                        , lightType2 = light2.lightType
                        , lightColor2 = light2.lightColor
                        , lightVector2 = light2.lightVector
                        , lightRadius2 = light2.lightRadius
                        , lightType3 = light3.lightType
                        , lightColor3 = light3.lightColor
                        , lightVector3 = light3.lightVector
                        , lightRadius3 = light3.lightRadius
                        , lightType4 = light4.lightType
                        , lightColor4 = light4.lightColor
                        , lightVector4 = light4.lightVector
                        , lightRadius4 = light4.lightRadius
                        , lightType5 = light5.lightType
                        , lightColor5 = light5.lightColor
                        , lightVector5 = light5.lightVector
                        , lightRadius5 = light5.lightRadius
                        , lightType6 = light6.lightType
                        , lightColor6 = light6.lightColor
                        , lightVector6 = light6.lightVector
                        , lightRadius6 = light6.lightRadius
                        , lightType7 = light7.lightType
                        , lightColor7 = light7.lightColor
                        , lightVector7 = light7.lightVector
                        , lightRadius7 = light7.lightRadius
                        }
                in
                WebGL.entityWith settings Shader.vertex Shader.ambient7 mesh uniforms

        AmbientLighting8 ambientProperties light1 light2 light3 light4 light5 light6 light7 light8 ->
            \settings eyePoint modelMatrix modelViewProjectionMatrix material gammaCorrection mesh ->
                let
                    uniforms =
                        { modelMatrix = modelMatrix
                        , modelViewProjectionMatrix = modelViewProjectionMatrix
                        , eyePoint = eyePoint
                        , baseColor = material.baseColor
                        , roughness = material.roughness
                        , metallic = material.metallic
                        , gammaCorrection = gammaCorrection
                        , ambientLightColor = ambientProperties.color
                        , ambientLookupTexture = ambientProperties.lookupTexture
                        , lightType1 = light1.lightType
                        , lightColor1 = light1.lightColor
                        , lightVector1 = light1.lightVector
                        , lightRadius1 = light1.lightRadius
                        , lightType2 = light2.lightType
                        , lightColor2 = light2.lightColor
                        , lightVector2 = light2.lightVector
                        , lightRadius2 = light2.lightRadius
                        , lightType3 = light3.lightType
                        , lightColor3 = light3.lightColor
                        , lightVector3 = light3.lightVector
                        , lightRadius3 = light3.lightRadius
                        , lightType4 = light4.lightType
                        , lightColor4 = light4.lightColor
                        , lightVector4 = light4.lightVector
                        , lightRadius4 = light4.lightRadius
                        , lightType5 = light5.lightType
                        , lightColor5 = light5.lightColor
                        , lightVector5 = light5.lightVector
                        , lightRadius5 = light5.lightRadius
                        , lightType6 = light6.lightType
                        , lightColor6 = light6.lightColor
                        , lightVector6 = light6.lightVector
                        , lightRadius6 = light6.lightRadius
                        , lightType7 = light7.lightType
                        , lightColor7 = light7.lightColor
                        , lightVector7 = light7.lightVector
                        , lightRadius7 = light7.lightRadius
                        , lightType8 = light8.lightType
                        , lightColor8 = light8.lightColor
                        , lightVector8 = light8.lightVector
                        , lightRadius8 = light8.lightRadius
                        }
                in
                WebGL.entityWith settings Shader.vertex Shader.ambient8 mesh uniforms

        NoAmbientLighting1 light1 ->
            \settings eyePoint modelMatrix modelViewProjectionMatrix material gammaCorrection mesh ->
                let
                    uniforms =
                        { modelMatrix = modelMatrix
                        , modelViewProjectionMatrix = modelViewProjectionMatrix
                        , eyePoint = eyePoint
                        , baseColor = material.baseColor
                        , roughness = material.roughness
                        , metallic = material.metallic
                        , gammaCorrection = gammaCorrection
                        , lightType1 = light1.lightType
                        , lightColor1 = light1.lightColor
                        , lightVector1 = light1.lightVector
                        , lightRadius1 = light1.lightRadius
                        }
                in
                WebGL.entityWith settings Shader.vertex Shader.noAmbient1 mesh uniforms

        NoAmbientLighting2 light1 light2 ->
            \settings eyePoint modelMatrix modelViewProjectionMatrix material gammaCorrection mesh ->
                let
                    uniforms =
                        { modelMatrix = modelMatrix
                        , modelViewProjectionMatrix = modelViewProjectionMatrix
                        , eyePoint = eyePoint
                        , baseColor = material.baseColor
                        , roughness = material.roughness
                        , metallic = material.metallic
                        , gammaCorrection = gammaCorrection
                        , lightType1 = light1.lightType
                        , lightColor1 = light1.lightColor
                        , lightVector1 = light1.lightVector
                        , lightRadius1 = light1.lightRadius
                        , lightType2 = light2.lightType
                        , lightColor2 = light2.lightColor
                        , lightVector2 = light2.lightVector
                        , lightRadius2 = light2.lightRadius
                        }
                in
                WebGL.entityWith settings Shader.vertex Shader.noAmbient2 mesh uniforms

        NoAmbientLighting3 light1 light2 light3 ->
            \settings eyePoint modelMatrix modelViewProjectionMatrix material gammaCorrection mesh ->
                let
                    uniforms =
                        { modelMatrix = modelMatrix
                        , modelViewProjectionMatrix = modelViewProjectionMatrix
                        , eyePoint = eyePoint
                        , baseColor = material.baseColor
                        , roughness = material.roughness
                        , metallic = material.metallic
                        , gammaCorrection = gammaCorrection
                        , lightType1 = light1.lightType
                        , lightColor1 = light1.lightColor
                        , lightVector1 = light1.lightVector
                        , lightRadius1 = light1.lightRadius
                        , lightType2 = light2.lightType
                        , lightColor2 = light2.lightColor
                        , lightVector2 = light2.lightVector
                        , lightRadius2 = light2.lightRadius
                        , lightType3 = light3.lightType
                        , lightColor3 = light3.lightColor
                        , lightVector3 = light3.lightVector
                        , lightRadius3 = light3.lightRadius
                        }
                in
                WebGL.entityWith settings Shader.vertex Shader.noAmbient3 mesh uniforms

        NoAmbientLighting4 light1 light2 light3 light4 ->
            \settings eyePoint modelMatrix modelViewProjectionMatrix material gammaCorrection mesh ->
                let
                    uniforms =
                        { modelMatrix = modelMatrix
                        , modelViewProjectionMatrix = modelViewProjectionMatrix
                        , eyePoint = eyePoint
                        , baseColor = material.baseColor
                        , roughness = material.roughness
                        , metallic = material.metallic
                        , gammaCorrection = gammaCorrection
                        , lightType1 = light1.lightType
                        , lightColor1 = light1.lightColor
                        , lightVector1 = light1.lightVector
                        , lightRadius1 = light1.lightRadius
                        , lightType2 = light2.lightType
                        , lightColor2 = light2.lightColor
                        , lightVector2 = light2.lightVector
                        , lightRadius2 = light2.lightRadius
                        , lightType3 = light3.lightType
                        , lightColor3 = light3.lightColor
                        , lightVector3 = light3.lightVector
                        , lightRadius3 = light3.lightRadius
                        , lightType4 = light4.lightType
                        , lightColor4 = light4.lightColor
                        , lightVector4 = light4.lightVector
                        , lightRadius4 = light4.lightRadius
                        }
                in
                WebGL.entityWith settings Shader.vertex Shader.noAmbient4 mesh uniforms

        NoAmbientLighting5 light1 light2 light3 light4 light5 ->
            \settings eyePoint modelMatrix modelViewProjectionMatrix material gammaCorrection mesh ->
                let
                    uniforms =
                        { modelMatrix = modelMatrix
                        , modelViewProjectionMatrix = modelViewProjectionMatrix
                        , eyePoint = eyePoint
                        , baseColor = material.baseColor
                        , roughness = material.roughness
                        , metallic = material.metallic
                        , gammaCorrection = gammaCorrection
                        , lightType1 = light1.lightType
                        , lightColor1 = light1.lightColor
                        , lightVector1 = light1.lightVector
                        , lightRadius1 = light1.lightRadius
                        , lightType2 = light2.lightType
                        , lightColor2 = light2.lightColor
                        , lightVector2 = light2.lightVector
                        , lightRadius2 = light2.lightRadius
                        , lightType3 = light3.lightType
                        , lightColor3 = light3.lightColor
                        , lightVector3 = light3.lightVector
                        , lightRadius3 = light3.lightRadius
                        , lightType4 = light4.lightType
                        , lightColor4 = light4.lightColor
                        , lightVector4 = light4.lightVector
                        , lightRadius4 = light4.lightRadius
                        , lightType5 = light5.lightType
                        , lightColor5 = light5.lightColor
                        , lightVector5 = light5.lightVector
                        , lightRadius5 = light5.lightRadius
                        }
                in
                WebGL.entityWith settings Shader.vertex Shader.noAmbient5 mesh uniforms

        NoAmbientLighting6 light1 light2 light3 light4 light5 light6 ->
            \settings eyePoint modelMatrix modelViewProjectionMatrix material gammaCorrection mesh ->
                let
                    uniforms =
                        { modelMatrix = modelMatrix
                        , modelViewProjectionMatrix = modelViewProjectionMatrix
                        , eyePoint = eyePoint
                        , baseColor = material.baseColor
                        , roughness = material.roughness
                        , metallic = material.metallic
                        , gammaCorrection = gammaCorrection
                        , lightType1 = light1.lightType
                        , lightColor1 = light1.lightColor
                        , lightVector1 = light1.lightVector
                        , lightRadius1 = light1.lightRadius
                        , lightType2 = light2.lightType
                        , lightColor2 = light2.lightColor
                        , lightVector2 = light2.lightVector
                        , lightRadius2 = light2.lightRadius
                        , lightType3 = light3.lightType
                        , lightColor3 = light3.lightColor
                        , lightVector3 = light3.lightVector
                        , lightRadius3 = light3.lightRadius
                        , lightType4 = light4.lightType
                        , lightColor4 = light4.lightColor
                        , lightVector4 = light4.lightVector
                        , lightRadius4 = light4.lightRadius
                        , lightType5 = light5.lightType
                        , lightColor5 = light5.lightColor
                        , lightVector5 = light5.lightVector
                        , lightRadius5 = light5.lightRadius
                        , lightType6 = light6.lightType
                        , lightColor6 = light6.lightColor
                        , lightVector6 = light6.lightVector
                        , lightRadius6 = light6.lightRadius
                        }
                in
                WebGL.entityWith settings Shader.vertex Shader.noAmbient6 mesh uniforms

        NoAmbientLighting7 light1 light2 light3 light4 light5 light6 light7 ->
            \settings eyePoint modelMatrix modelViewProjectionMatrix material gammaCorrection mesh ->
                let
                    uniforms =
                        { modelMatrix = modelMatrix
                        , modelViewProjectionMatrix = modelViewProjectionMatrix
                        , eyePoint = eyePoint
                        , baseColor = material.baseColor
                        , roughness = material.roughness
                        , metallic = material.metallic
                        , gammaCorrection = gammaCorrection
                        , lightType1 = light1.lightType
                        , lightColor1 = light1.lightColor
                        , lightVector1 = light1.lightVector
                        , lightRadius1 = light1.lightRadius
                        , lightType2 = light2.lightType
                        , lightColor2 = light2.lightColor
                        , lightVector2 = light2.lightVector
                        , lightRadius2 = light2.lightRadius
                        , lightType3 = light3.lightType
                        , lightColor3 = light3.lightColor
                        , lightVector3 = light3.lightVector
                        , lightRadius3 = light3.lightRadius
                        , lightType4 = light4.lightType
                        , lightColor4 = light4.lightColor
                        , lightVector4 = light4.lightVector
                        , lightRadius4 = light4.lightRadius
                        , lightType5 = light5.lightType
                        , lightColor5 = light5.lightColor
                        , lightVector5 = light5.lightVector
                        , lightRadius5 = light5.lightRadius
                        , lightType6 = light6.lightType
                        , lightColor6 = light6.lightColor
                        , lightVector6 = light6.lightVector
                        , lightRadius6 = light6.lightRadius
                        , lightType7 = light7.lightType
                        , lightColor7 = light7.lightColor
                        , lightVector7 = light7.lightVector
                        , lightRadius7 = light7.lightRadius
                        }
                in
                WebGL.entityWith settings Shader.vertex Shader.noAmbient7 mesh uniforms

        NoAmbientLighting8 light1 light2 light3 light4 light5 light6 light7 light8 ->
            \settings eyePoint modelMatrix modelViewProjectionMatrix material gammaCorrection mesh ->
                let
                    uniforms =
                        { modelMatrix = modelMatrix
                        , modelViewProjectionMatrix = modelViewProjectionMatrix
                        , eyePoint = eyePoint
                        , baseColor = material.baseColor
                        , roughness = material.roughness
                        , metallic = material.metallic
                        , gammaCorrection = gammaCorrection
                        , lightType1 = light1.lightType
                        , lightColor1 = light1.lightColor
                        , lightVector1 = light1.lightVector
                        , lightRadius1 = light1.lightRadius
                        , lightType2 = light2.lightType
                        , lightColor2 = light2.lightColor
                        , lightVector2 = light2.lightVector
                        , lightRadius2 = light2.lightRadius
                        , lightType3 = light3.lightType
                        , lightColor3 = light3.lightColor
                        , lightVector3 = light3.lightVector
                        , lightRadius3 = light3.lightRadius
                        , lightType4 = light4.lightType
                        , lightColor4 = light4.lightColor
                        , lightVector4 = light4.lightVector
                        , lightRadius4 = light4.lightRadius
                        , lightType5 = light5.lightType
                        , lightColor5 = light5.lightColor
                        , lightVector5 = light5.lightVector
                        , lightRadius5 = light5.lightRadius
                        , lightType6 = light6.lightType
                        , lightColor6 = light6.lightColor
                        , lightVector6 = light6.lightVector
                        , lightRadius6 = light6.lightRadius
                        , lightType7 = light7.lightType
                        , lightColor7 = light7.lightColor
                        , lightVector7 = light7.lightVector
                        , lightRadius7 = light7.lightRadius
                        , lightType8 = light8.lightType
                        , lightColor8 = light8.lightColor
                        , lightVector8 = light8.lightVector
                        , lightRadius8 = light8.lightRadius
                        }
                in
                WebGL.entityWith settings Shader.vertex Shader.noAmbient8 mesh uniforms

        DummyLighting ->
            \settings eyePoint modelMatrix modelViewProjectionMatrix material gammaCorrection mesh ->
                let
                    uniforms =
                        { modelMatrix = modelMatrix
                        , modelViewProjectionMatrix = modelViewProjectionMatrix
                        , baseColor = material.baseColor
                        , gammaCorrection = gammaCorrection
                        }
                in
                WebGL.entityWith settings Shader.vertex Shader.dummy mesh uniforms


toEntity : RenderProperties -> Frame3d -> Types.Drawable -> WebGL.Entity
toEntity renderProperties modelFrame drawable =
    let
        modelMatrix =
            Frame3d.modelMatrix modelFrame

        modelViewMatrix =
            Frame3d.modelViewMatrix renderProperties.cameraFrame modelFrame

        projectionMatrix =
            renderProperties.projectionMatrix

        modelViewProjectionMatrix =
            Math.Matrix4.mul projectionMatrix modelViewMatrix

        cullSetting =
            if Frame3d.isRightHanded modelFrame then
                WebGL.Settings.back
            else
                WebGL.Settings.front

        settings =
            [ WebGL.Settings.DepthTest.default
            , WebGL.Settings.cullFace cullSetting
            ]
    in
    case drawable of
        Types.ColoredGeometry color boundingBox mesh ->
            let
                uniforms =
                    { modelMatrix = modelMatrix
                    , modelViewProjectionMatrix = modelViewProjectionMatrix
                    , color = color
                    }
            in
            WebGL.entityWith settings
                Shader.simpleVertex
                Shader.simple
                mesh
                uniforms

        Types.ShadedGeometry material boundingBox mesh ->
            case material of
                Types.PhysicallyBasedMaterial materialProperties ->
                    renderProperties.physicallyBasedRenderer
                        settings
                        renderProperties.eyePoint
                        modelMatrix
                        modelViewProjectionMatrix
                        materialProperties
                        renderProperties.gammaCorrection
                        mesh

                Types.EmissiveMaterial color ->
                    let
                        ( r, g, b ) =
                            Vector3.toTuple color

                        gammaCorrection =
                            renderProperties.gammaCorrection

                        gammaCorrectedColor =
                            Vector3.vec3
                                (r ^ gammaCorrection)
                                (g ^ gammaCorrection)
                                (b ^ gammaCorrection)

                        uniforms =
                            { modelMatrix = modelMatrix
                            , modelViewProjectionMatrix = modelViewProjectionMatrix
                            , gammaCorrectedColor = gammaCorrectedColor
                            }
                    in
                    WebGL.entityWith settings
                        Shader.vertex
                        Shader.emissive
                        mesh
                        uniforms


collectEntities : RenderProperties -> Frame3d -> Node -> List WebGL.Entity -> List WebGL.Entity
collectEntities renderProperties placementFrame node accumulated =
    case node of
        Types.TransformedNode frame childNode ->
            collectEntities renderProperties
                (Frame3d.placeIn placementFrame frame)
                childNode
                accumulated

        Types.LeafNode drawable ->
            toEntity renderProperties placementFrame drawable :: accumulated

        Types.GroupNode childNodes ->
            List.foldl (collectEntities renderProperties placementFrame)
                accumulated
                childNodes

        Types.EmptyNode ->
            accumulated


toEntities : List Light -> Camera -> Node -> List WebGL.Entity
toEntities =
    toEntitiesWith []


toEntitiesWith : List RenderOption -> List Light -> Camera -> Node -> List WebGL.Entity
toEntitiesWith options lights camera rootNode =
    let
        cameraFrame =
            Camera.frame camera

        renderProperties =
            { cameraFrame = cameraFrame
            , eyePoint = Point3d.toVec3 (Frame3d.originPoint cameraFrame)
            , projectionMatrix = Camera.projectionMatrix camera
            , physicallyBasedRenderer = physicallyBasedRendererFor lights
            , gammaCorrection = getGammaCorrection options
            }
    in
    collectEntities renderProperties Frame3d.xyz rootNode []


render : List Light -> Camera -> Node -> Html msg
render =
    renderWith []


type RenderOption
    = DevicePixelRatio Float
    | GammaCorrection Float


devicePixelRatio : Float -> RenderOption
devicePixelRatio =
    DevicePixelRatio


gammaCorrection : Float -> RenderOption
gammaCorrection =
    GammaCorrection


getDevicePixelRatio : List RenderOption -> Float
getDevicePixelRatio options =
    let
        defaultValue =
            1.0

        update option oldValue =
            case option of
                DevicePixelRatio newValue ->
                    newValue

                _ ->
                    oldValue
    in
    List.foldl update defaultValue options


getGammaCorrection : List RenderOption -> Float
getGammaCorrection options =
    let
        defaultValue =
            0.45

        update option oldValue =
            case option of
                GammaCorrection newValue ->
                    newValue

                _ ->
                    oldValue
    in
    List.foldl update defaultValue options


renderWith : List RenderOption -> List Light -> Camera -> Node -> Html msg
renderWith options lights camera rootNode =
    let
        width =
            Camera.screenWidth camera

        height =
            Camera.screenHeight camera

        devicePixelRatio =
            getDevicePixelRatio options
    in
    WebGL.toHtml
        [ Html.Attributes.width (round (devicePixelRatio * width))
        , Html.Attributes.height (round (devicePixelRatio * height))
        , Html.Attributes.style
            [ ( "width", toString width ++ "px" )
            , ( "height", toString height ++ "px" )
            ]
        ]
        (toEntitiesWith options lights camera rootNode)