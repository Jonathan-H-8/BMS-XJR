/******************** (C) COPYRIGHT  源地工作室 ********************************
 * 文件名  ：IO_CTRL.c
 * 描述    ：IO口引脚配置     
 * 作者    ：zhuoyingxingyu
 * 淘宝    ：源地工作室http://vcc-gnd.taobao.com/
 * 论坛地址：极客园地-嵌入式开发论坛http://vcc-gnd.com/
 * 版本更新: 2016-04-08
 * 硬件连接: D1->PC13;D2->PB0;D3->PB1
 * 调试方式：J-Link-OB
**********************************************************************************/	

//头文件
#include "IO_CTRL.h"

 /**
  * @file   GPIO_Config
  * @brief  IO口引脚配置
  * @param  无
  * @retval 无
  */
void IO_CTRL_Config(void)
{	
    //定义一个GPIO_InitTypeDef 类型的结构体
    GPIO_InitTypeDef  GPIO_InitStructure;	
    RCC_APB2PeriphClockCmd(GPIOA_RCC| GPIOB_RCC,ENABLE);//使能GPIO的外设时钟
	  
	  
    /*D1*/
    /*D3*/
    GPIO_InitStructure.GPIO_Pin =MCU_WAKE_BQ;
    GPIO_InitStructure.GPIO_Mode = GPIO_Mode_Out_PP; 			 
    GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
    GPIO_Init(GPIOB_PORT, &GPIO_InitStructure);
	
		
		
		
		
			
}


