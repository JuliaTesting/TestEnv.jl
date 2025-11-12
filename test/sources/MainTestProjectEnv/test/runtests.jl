using MainTestProjectEnv
using MainEnv
using Test

@test MainTestProjectEnv.bar() == MainEnv.foo()
