// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";
interface IDreamAcademyLending {
	function deposit(address token_addr, uint256 amount) external payable;
	function borrow(address token_addr, uint256 amount) external payable;
	function repay(address token_addr, uint256 amount) external payable;
	function liquidate(address user, address token_addr, uint256 amount) external;
	function withdraw(address token_addr, uint256 amount) external;
}
interface IPriceOracle {
	function getPrice(address _asset) external view returns (uint256);
	function setPrice(address _asset, uint256 _price) external;
}
struct deposit_st{
	uint eth;
	uint eth_val;
	uint usdc_val;
	uint usdc;
}

contract DreamAcademyLending is IDreamAcademyLending {
	mapping(address=>deposit_st) deposit_list;
	mapping(address=>deposit_st) loan_list;
	mapping(address=>deposit_st) loan_list_bak;
	IPriceOracle oracle;
	IERC20 usdc;
	constructor(IPriceOracle _oracle, address _usdc){
		usdc = IERC20(_usdc);
		oracle = _oracle;
	}
	function chkTk(address token_addr) internal returns(bool){
		bool ret;
		if(token_addr == address(0)){
			ret = true;
		}
		else{
			ret = false;
		}
		return ret;
	}
	function deposit(address token_addr, uint256 amount) external payable{
		bool stat = chkTk(token_addr);
		uint256 val = msg.value;
		if(stat){
			//eth
			require(amount <= msg.value, "val error");
			deposit_list[msg.sender].eth = msg.value;
			deposit_list[msg.sender].eth_val = oracle.getPrice(address(0));
		}
		else{
			usdc.transferFrom(msg.sender, address(this), amount);
			deposit_list[msg.sender].usdc = amount;
			deposit_list[msg.sender].usdc_val = oracle.getPrice(address(usdc));
			
		}
	}
	function calcTk(uint256 land_value) internal returns(uint256){
		uint256 divs = 2;
		return land_value / divs;		
	}
	function deposit_chk() internal {

	}
	function borrow(address token_addr, uint256 amount) external payable{
		// token을 amount만큼 빌리고 싶다
		uint256 usdc_value = oracle.getPrice(address(usdc));
		uint256 eth_value  = oracle.getPrice(address(0));
		bool chk = chkTk(token_addr);
		uint256 land_value;
		uint256 tmp_value;
		uint256 pwan;
		if(chk) { // token addr : usdc 이더리움 빌리고 싶음
					//이더면 true
			uint borrowd = loan_list[msg.sender].eth * eth_value;
			tmp_value = eth_value * deposit_list[msg.sender].usdc - borrowd;
			land_value = tmp_value / eth_value; // 빌릴 것 1개의 가치
			// 총 가치 / 이더 = 총 몇개 빌릴 수 있는지
			//	usdc -> eth
			pwan = (eth_value * amount) *2;
			
			if(tmp_value >= pwan){
				loan_list[msg.sender].eth += amount;
				loan_list[msg.sender].eth_val = eth_value;
				//loan_list_bak[msg.sender].eth += amount;
			//	deposit_list[msg.sender].usdc -= (pwan / usdc_value ) ;
				usdc.transferFrom(msg.sender, address(this), pwan);
				address(msg.sender).call{value:amount}("");
			}
			else{
				revert("pwan error");
			}
		}
		else{
			// eth -> usdc
			uint borrowd = loan_list[msg.sender].usdc * loan_list[msg.sender].usdc_val;
			tmp_value = eth_value * deposit_list[msg.sender].eth;
			land_value = tmp_value / usdc_value;
			pwan = (usdc_value * (amount*2)) + borrowd*2;
			console.log(borrowd);
			console.log("tmp val");
			console.log(tmp_value);
			console.log("pwan");
			console.log(pwan);
			if(tmp_value >= pwan){ // 총 예치한  가치가 빌릴 담보보다 많으면
				loan_list[msg.sender].usdc += amount;
				loan_list[msg.sender].usdc_val = usdc_value;
				
				//loan_list_bak[msg.sender].usdc += amount;
			//	deposit_list[msg.sender].eth -= (pwan / eth_value);
				usdc.transfer(msg.sender, amount);
			}
			else{
				revert("pwan error");
			}
		}
		/*
		console.log("usdc val");
		console.log(usdc_value);
		console.log("eth val");
		console.log(eth_value);
		console.log(usdc.balanceOf(msg.sender));
		*/
		
	}
	function repay(address token_addr, uint256 amount) external payable{
		bool chk = chkTk(token_addr);
		if(chk){
			require(loan_list[msg.sender].eth >= amount, "no repay");
			require(deposit_list[msg.sender].eth >= amount, "no val");
			loan_list[msg.sender].eth -= amount;
		}
		else{
			require(loan_list[msg.sender].usdc >= amount, "no repay");
			require(usdc.balanceOf(msg.sender) >= amount, "no val");
			require(usdc.allowance(msg.sender, address(this)) >= amount, "");
			usdc.transferFrom(msg.sender, address(this), amount);
			loan_list[msg.sender].usdc -= amount;
		}

	}
	function liquidate(address user, address token_addr, uint256 amount) external{
		//user가 빌린 금액을 25% 이상 값아주지 못함
		uint256 usdc_value = oracle.getPrice(address(usdc));
		uint256 eth_value  = oracle.getPrice(address(0));
		bool chk = chkTk(token_addr);
		if(chk){//이더 갚아줄 때
			console.log('asdfasfasfas');
			uint256 limit = loan_list[user].eth /4;
			uint256 liquid = loan_list_bak[user].eth;
			require(limit >= (liquid + amount), "25%");
			loan_list_bak[user].eth += amount;
			loan_list[user].eth -= amount;
			
		}
		else{// usdc 갚아줄 때
			console.log("abcdsorisori");
			uint256 limit = loan_list[user].usdc /4;
			uint256 liquid = loan_list_bak[user].usdc;
			uint total_depo_val = deposit_list[user].eth * eth_value + deposit_list[user].usdc * usdc_value;
			uint256 total_borrow_val = loan_list[user].eth * eth_value + loan_list[user].usdc * usdc_value;
			console.log(total_borrow_val);
			console.log(total_depo_val);
			uint before_deposit = deposit_list[user].eth * deposit_list[user].eth_val;
			uint256 ltv = (total_borrow_val*100/ total_depo_val);
			uint befo_diff_after = total_depo_val*100/ before_deposit;
			console.log(befo_diff_after);
			console.log(ltv);
			require(befo_diff_after >= 75, "diff");
			require(ltv >= 75, "ltv 75 under");
			require(limit >= (liquid + amount), "25%");
			loan_list_bak[user].usdc += amount;
			loan_list[user].usdc -= amount;

		}
	}
	function withdraw(address token_addr, uint256 amount) external{
		bool chk = chkTk(token_addr);
		if(chk){ // eth withdraw
			uint total_value = deposit_list[msg.sender].eth * deposit_list[msg.sender].eth_val;
			total_value -= loan_list[msg.sender].usdc * loan_list[msg.sender].usdc_val;
			total_value = total_value / oracle.getPrice(address(0));
			require(deposit_list[msg.sender].eth >= amount, "withdraw error, not money");
			require(total_value >= amount, "locked");
			deposit_list[msg.sender].eth -= amount;
			address(msg.sender).call{value:amount}("");
		}
		else{ // usdc withdraw
			require(deposit_list[msg.sender].usdc >= amount, "withdraw error, not money");
			deposit_list[msg.sender].usdc -= amount;
			usdc.transfer(msg.sender, amount);
		}

	}
	function initializeLendingProtocol(address a1) external payable{
		// ???
		usdc.transferFrom(msg.sender, address(this), msg.value);
	}
	function getAccruedSupplyAmount(address a1)external payable returns(uint){
		uint ret = 0;
		return ret;
	}
}
