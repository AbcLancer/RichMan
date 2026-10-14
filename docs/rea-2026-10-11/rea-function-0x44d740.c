
void __thiscall FUN_0044d740(void *this,int param_1,undefined4 param_2)

{
  float fVar1;
  
  if (param_1 < 0) {
    *(undefined4 *)((int)this + 0xe8) = 0;
    fVar1 = -0.32;
  }
  else {
    *(int *)((int)this + 0xec) = param_1;
    *(undefined4 *)((int)this + 0xe8) = 1;
    *(double *)((int)this + 0xf0) = (double)(param_1 + 0x30);
    *(undefined4 *)((int)this + 0x114) = param_2;
    fVar1 = -1.0;
  }
  FUN_00457c10(this,fVar1,-0.5);
  *(undefined4 *)((int)this + 0x100) = 0;
  *(undefined4 *)((int)this + 0x108) = 0;
  *(undefined4 *)((int)this + 0xd8) = 0;
  *(undefined4 *)((int)this + 0xf8) = 0;
  *(undefined4 *)((int)this + 0x104) = 0;
  *(undefined4 *)((int)this + 0x110) = 0;
  *(undefined4 *)((int)this + 0x10c) = 0xbff00000;
  return;
}

