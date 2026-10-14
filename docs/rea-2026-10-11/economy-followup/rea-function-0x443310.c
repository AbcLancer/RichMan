
void __thiscall FUN_00443310(void *this,uint param_1)

{
  if (param_1 != 1) {
    if (param_1 == 2) {
      *(uint *)((int)this + 0x50) = *(uint *)((int)this + 0x50) & 0xfffffffb;
      *(undefined4 *)((int)this + 0x60) = 0;
      *(undefined4 *)((int)this + 100) = 0;
      *(uint *)((int)this + 0x50) = *(uint *)((int)this + 0x50) | 2;
      return;
    }
    if (param_1 == 4) {
      *(uint *)((int)this + 0x50) = *(uint *)((int)this + 0x50) & 0xfffffffd;
      *(undefined4 *)((int)this + 0x60) = 0;
      *(undefined4 *)((int)this + 100) = 0;
      *(uint *)((int)this + 0x50) = *(uint *)((int)this + 0x50) | 4;
      return;
    }
    if (param_1 == 8) {
      *(undefined4 *)((int)this + 0x58) = 0;
      *(undefined4 *)((int)this + 0x5c) = 0;
    }
  }
  *(uint *)((int)this + 0x50) = *(uint *)((int)this + 0x50) | param_1;
  return;
}

