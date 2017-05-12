/*==============================================================================
 Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

 Vuforia is a trademark of PTC Inc., registered in the United States and other 
 countries.
 ==============================================================================*/

const char* fragmentShader = MAKESTRING(
precision mediump float;
varying vec2 texCoord;

uniform sampler2D texSampler2D;

void main()
{
    gl_FragColor = texture2D(texSampler2D, texCoord);
}
);
