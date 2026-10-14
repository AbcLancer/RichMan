
void __thiscall FUN_0044d1c0(void *this,int *param_1)

{
  int iVar1;
  
  iVar1 = FUN_00429c60(param_1);
  if (iVar1 < 1) {
    *(undefined4 *)((int)this + 0x110) = 0;
    *(undefined4 *)((int)this + 0xf0) = 2;
    *(undefined4 *)((int)this + 0x114) = 0x40000000;
  }
  else {
    *(undefined4 *)((int)this + 0x110) = 0;
    *(undefined4 *)((int)this + 0xf0) = 1;
    *(undefined4 *)((int)this + 0x114) = 0x3ff00000;
  }
  *(int *)((int)this + 0x11c) = *(int *)((int)this + 0x11c) * iVar1;
  *(int *)((int)this + 0x128) = iVar1;
  return;
}

