
void __thiscall FUN_00423250(void *this,int param_1)

{
  *(int *)((int)this + 0x88) = param_1;
  if (param_1 != 0) {
    *(undefined4 *)((int)this + 0x98) = 0;
    *(undefined4 *)((int)this + 0x8c) = 0;
    *(undefined4 *)((int)this + 0x80) = 0;
    return;
  }
  *(undefined4 *)((int)this + 0x98) = 1;
  *(undefined4 *)((int)this + 0x8c) = 0;
  *(undefined4 *)((int)this + 0x80) = 0;
  return;
}

