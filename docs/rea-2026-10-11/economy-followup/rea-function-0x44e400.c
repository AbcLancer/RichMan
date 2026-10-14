
void __thiscall FUN_0044e3e0(void *this,short *param_1,int param_2)

{
  int *piVar1;
  char *pcVar2;
  short *psVar3;
  undefined1 *puVar4;
  int *piVar5;
  
  psVar3 = param_1;
  if (0 < param_2) {
    piVar5 = (int *)((int)this + 200);
    puVar4 = (undefined1 *)((int)this + 0x108);
    param_1 = (short *)param_2;
    do {
      *(undefined4 *)(*piVar5 + 0x68) = 0;
      piVar5[8] = (int)*psVar3;
      piVar1 = (int *)FUN_0041f010(&DAT_004d9498,(int)*psVar3);
      FUN_00485290(puVar4,(byte *)s__s__d_0049f6bc);
      pcVar2 = (char *)FUN_0042a8f0(&DAT_005090b0,*piVar1 + 0x2329);
      FUN_00457b80((void *)*piVar5,pcVar2);
      piVar5 = piVar5 + 1;
      psVar3 = psVar3 + 1;
      puVar4 = puVar4 + 0x40;
      param_1 = (short *)((int)param_1 + -1);
    } while (param_1 != (short *)0x0);
    *(int *)((int)this + 0x308) = param_2;
    return;
  }
  *(int *)((int)this + 0x308) = param_2;
  return;
}

