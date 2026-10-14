
void __thiscall FUN_0041ebf0(void *this,int param_1,int *param_2,int param_3,int param_4)

{
  int iVar1;
  byte *pbVar2;
  int *piVar3;
  
  if (param_3 <= param_4) {
    iVar1 = param_3 * 0x230;
    param_3 = (param_4 - param_3) + 1;
    piVar3 = (int *)(iVar1 + 0x22c + (int)this);
    do {
      iVar1 = piVar3[-1];
      if (iVar1 <= *piVar3) {
        pbVar2 = (byte *)((int)this + iVar1 * 0xc + 0x6dc0);
        do {
          if ((*pbVar2 & 4) == 0) {
            *(short *)(param_1 + *param_2 * 2) = (short)iVar1;
            *param_2 = *param_2 + 1;
          }
          iVar1 = iVar1 + 1;
          pbVar2 = pbVar2 + 0xc;
        } while (iVar1 <= *piVar3);
      }
      piVar3 = piVar3 + 0x8c;
      param_3 = param_3 + -1;
    } while (param_3 != 0);
  }
  return;
}

