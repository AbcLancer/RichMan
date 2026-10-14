
void __fastcall FUN_00441360(void *param_1)

{
  int iVar1;
  undefined4 *puVar2;
  int iVar3;
  int iVar4;
  float10 fVar5;
  
  if ((1 < DAT_004c2354) && (iVar4 = 0, 0 < *(int *)((int)param_1 + 8))) {
    do {
      iVar1 = FUN_00441000(param_1,iVar4);
      if (*(int *)(iVar1 + 0x40) != 0) {
        if (*(int *)(iVar1 + 0x1b4) < 0x1e) {
          *(undefined4 *)(iVar1 + 0xc4 + *(int *)(iVar1 + 0x1b4) * 4) =
               *(undefined4 *)(iVar1 + 0x68);
          fVar5 = FUN_0043fe70(iVar1);
          *(float *)(iVar1 + 0x13c + *(int *)(iVar1 + 0x1b4) * 4) = (float)fVar5;
          *(int *)(iVar1 + 0x1b4) = *(int *)(iVar1 + 0x1b4) + 1;
        }
        else {
          puVar2 = (undefined4 *)(iVar1 + 0xc4);
          iVar3 = 0x1d;
          do {
            *puVar2 = puVar2[1];
            puVar2[0x1e] = puVar2[0x1f];
            puVar2 = puVar2 + 1;
            iVar3 = iVar3 + -1;
          } while (iVar3 != 0);
          *(undefined4 *)(iVar1 + 0x138) = *(undefined4 *)(iVar1 + 0x68);
          fVar5 = FUN_0043fe70(iVar1);
          *(float *)(iVar1 + 0x1b0) = (float)fVar5;
        }
      }
      iVar4 = iVar4 + 1;
    } while (iVar4 < *(int *)((int)param_1 + 8));
  }
  return;
}

