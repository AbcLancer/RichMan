
void __thiscall
FUN_0044d950(void *this,uint param_1,float *param_2,float *param_3,float *param_4,float *param_5)

{
  int iVar1;
  uint uVar2;
  
  uVar2 = param_1 & 0x80000003;
  if ((int)uVar2 < 0) {
    uVar2 = (uVar2 - 1 | 0xfffffffc) + 1;
  }
  iVar1 = ((int)(param_1 + ((int)param_1 >> 0x1f & 3U)) >> 2) * 0x2b;
  *param_2 = (float)(int)(uVar2 * 0x2b + 0xe) * 0.0025 + *(float *)((int)this + 0x1c);
  *param_3 = (*(float *)((int)this + 0x28) + *(float *)((int)this + 0x20)) -
             (float)(iVar1 + 0x85) * 0.0033333334;
  *param_4 = (float)(int)(uVar2 * 0x2b + 0x35) * 0.0025 + *(float *)((int)this + 0x1c);
  *param_5 = (*(float *)((int)this + 0x28) + *(float *)((int)this + 0x20)) -
             (float)(iVar1 + 0x5e) * 0.0033333334;
  return;
}

