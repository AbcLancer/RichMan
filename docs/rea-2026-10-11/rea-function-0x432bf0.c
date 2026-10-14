
void __thiscall FUN_00432bf0(void *this,int param_1)

{
  float fVar1;
  
  fVar1 = (float)param_1 + *(float *)((int)this + 0x38);
  *(float *)((int)this + 0x38) = fVar1;
  if (fVar1 < 0.0) {
    *(undefined4 *)((int)this + 0x38) = 0;
  }
  *(byte *)((int)this + 0x40) = *(byte *)((int)this + 0x40) | 1;
  return;
}

