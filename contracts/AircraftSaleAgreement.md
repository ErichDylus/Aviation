/** draft aircraft sale agreement template drafted in OpenLaw's markup 
for demonstration purposes only, not for commercial or any other use nor to be construed as any legal or financial advice
this code is distributed WITHOUT ANY WARRANTY, including but not limited to any implied warranty of merchantibility or fitness for a particular purpose
**/ see: https://lib.openlaw.io/web/default/template/Aircraft%20Sale%20Agreement

// TODO: incorporate Escrow.sol, API triggers 

<%
==Seller==
[[Seller Address: EthAddress]]
[[Seller Email: Identity]]
==Buyer==
[[Buyer Address: EthAddress]]
[[Buyer Email: Identity]]
==Aircraft==
[[Aircraft Description]]
[[Purchase Price: Number]]
%>

\centered**Aircraft Sale Agreement**

The seller described at, and possessing control of, the private key to, the Ethereum address **[[Seller ETH Address: EthAddress]]** (the "Seller"), has good and marketable title to that certain **[[Airframe Description]]** bearing MSN **[[MSN]]** and Registration Number **[[Registration Number]]** including such Engines, APU, Parts, and Aircraft Documents identified in __Exhibit A__ attached hereto (collectively, the "Aircraft"), free and clear of any liens, mortgages, pledges, security interests, and other encumbrances of any kind, and Seller hereby does agree to sell, convey, transfer and assign, free and clear of all liens, charges, encumbrances, debts, obligations and liabilities whatsoever, all of the Seller's right, title and interest in and to the Aircraft "AS-IS AND WITH ALL FAULTS" to the buyer described at, and possessing control of, the private key to, Ethereum address **[[Buyer ETH Address: EthAddress]]** (the "Buyer"), pursuant to the terms and conditions hereafter set forth. This aircraft sale agreement (the "Agreement") is entered into as of [[Effective Date: Date]].  

The purchase price for the Aircraft is agreed by the parties hereto to be **[[Purchase Price: Number]] ether** (the "Purchase Price"). Prior to execution of this Agreement, Buyer shall cause the transfer of the Purchase Price via the following: [[Escrow: Clause("Escrow Ether")]] (the "Smart Contract").

The Seller shall promptly ensure the Aircraft's location at or arrange for the Aircraft’s delivery to, at Seller's sole cost and expense, [[Jurisdiction or specific Delivery Location]] within three business days of Buyer's transfer of the Purchase Price to the Smart Contract.  Seller will cause to be invoked the appropriate function in the Smart Contract to confirm delivery. 

Buyer will cause to be invoked the appropriate function in the Smart Contract to confirm acceptance of the Aircraft or otherwise confirm such acceptance in writing, at which time risk of loss, damage, or destruction of the Aircraft shall pass from Seller to Buyer. 

If the Aircraft has any material discrepancies, as determined in Buyer's reasonable discretion, from the Delivery Condition as defined and further set forth in __Exhibit B__ attached hereto (the "Delivery Condition"), Buyer may reject the Aircraft by invoking the appropriate function in the Smart Contract to reject the Aircraft or otherwise confirm such rejection in writing; upon such rejection, the Purchase Price shall be returned to the Buyer either by operation of the Smart Contract or by the Buyer invoking the appropriate function in the Smart Contract, as applicable, and this Agreement shall terminate, and neither party shall have any obligation to the other party.

\centered**Arbitration**

Any dispute, claim or controversy arising out of or relating to this Agreement or the breach, termination, enforcement, interpretation or validity thereof, including the determination of the scope or applicability of this Agreement to arbitrate, shall be resolved by TLDR arbiters under lexDAO Arbitration Rules. Judgment on any applicable arbitral award may be entered in any court having jurisdiction. This clause shall not preclude the parties from seeking provisional remedies in aid of arbitration from a court of appropriate jurisdiction.


**AGREED BY: **


**Seller**

[[Seller Email: Identity | Signature]]
_____________

**Buyer**

[[Buyer Email: Identity | Signature]]

\centered__Exhibit A - Aircraft Details__
[[Type Information Here: LargeText]]

\centered__Exhibit B - Delivery Condition__
[[Type Information Here: LargeText]]
