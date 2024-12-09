(SELECT

	COALESCE(cl.name, cl2.name, sh.name) AS client_name,
	SUM(cspp.gross_value) AS valor_bruto,
 
 	CASE
 		WHEN funds.name = 'REAL INVESTOR INSTITUCIONAL FIC FIA BDR NÍVEL I' THEN 'REAL INVESTOR INSTITUCIONAL FIC FIA'
 		WHEN funds.name = 'REAL INVESTOR CRÉDITO ESTRUTURADO FIC FIM CP' THEN 'REAL INVESTOR CRÉDITO ESTRUTURADO 90 FIC FIM CP'
 		WHEN funds.name = 'REAL INVESTOR II FIC FI FINANCEIRO AÇÕES RESPONSABILIDADE LIMITADA' THEN 'REAL INVESTOR II FIC FIA'
 		ELSE funds.name
 	END AS produto,
 
 	CASE
 		WHEN sh.id IN (11100, 50636, 11098) THEN 'Plataformas'
 		WHEN sh.id IN (11167, 472, 371, 370, 372, 1, 35532) THEN 'Real Investor - Wealth'
 		WHEN sh.id IN (68788, 70182) THEN 'MFO | Institucional' -- Planos da Fundação Itaipu
 		WHEN sh.allocator_id IS NOT NULL THEN 'MFO | Institucional'
 		WHEN COALESCE(cbw.id, caw.id) IS NULL OR (cbw.id IS NOT NULL AND cbw.annulled_at IS NOT NULL) THEN 'Plataformas'
 		WHEN COALESCE(cl.user_id, cl2.user_id) IS NOT NULL THEN 'Real Investor - Wealth'
 		WHEN COALESCE(cl.attendance_id, cl2.attendance_id) <> 11 AND cbw.annulled_at IS NULL THEN 'Real Investor - Wealth'
 		WHEN COALESCE(cl.attendance_id, cl2.attendance_id) = 11 AND sh.distributor_id <> 2 THEN 'Real Investor - Wealth'
 		WHEN COALESCE(cl.attendance_id, cl2.attendance_id) = 11 AND sh.distributor_id = 2 THEN 'Distribuição Própria'
 	END AS layer1,
 
 	CASE
 		WHEN sh.id IN (50636, 11098) THEN 'Icatu'
 		WHEN sh.id = 11100 THEN 'Xp Investimentos CCTVM'
 		WHEN sh.id IN (68788, 70182) THEN 'Fundação Itaipu' -- Planos da Fundação Itaipu
 		WHEN sh.allocator_id IS NOT NULL THEN companies.name
		WHEN COALESCE(cl.user_id, cl2.user_id) IS NOT NULL THEN 'COLABORADOR'
 		WHEN COALESCE(cl.is_non_resident_investor, cl2.is_non_resident_investor) = TRUE THEN 'INR'
 		ELSE com2.name
 	END AS layer2,
 	
 	CASE
 		WHEN pr.id IN (17, 3, 4, 1, 7, 24, 27) THEN 'AÇÕES BRASIL'
 		WHEN pr.id IN (9) THEN 'AÇÕES EXTERIOR'
 		WHEN pr.id IN (8, 11) THEN 'MULTIMERCADO'
 		WHEN pr.id IN (13, 5) THEN 'IMOBILIÁRIO'
 		WHEN pr.id IN (6, 23) THEN 'CRÉDITO'
 		ELSE 'EXCLUSIVO'
 	END AS estrategia,
 	cspp.reference_date
	
FROM fund_services.current_shareholder_product_positions cspp

JOIN fund_services.shareholders sh ON sh.id = cspp.shareholder_id
JOIN fund_services.products pr ON pr.id = cspp.product_id
JOIN fund_services.funds ON funds.id = pr.fund_id
 
LEFT JOIN fund_services.allocators al ON al.id = sh.allocator_id
LEFT JOIN fund_services.funds fu2 ON fu2.id = al.fund_id
LEFT JOIN fund_services.managers ON managers.id = fu2.manager_id
LEFT JOIN public.companies ON companies.id = managers.company_id
 
LEFT JOIN fund_services.distributors dis ON sh.distributor_id = dis.id
LEFT JOIN public.companies com2 ON com2.id = dis.company_id

LEFT JOIN
 	(
		SELECT cbw.*, br.company_id AS broker_company_id
		FROM wealth.client_broker_wallets AS cbw
		JOIN wealth.brokers AS br ON br.id = cbw.broker_id
	) AS cbw
ON cbw.code = sh.pco_code AND cbw.broker_company_id = dis.company_id

LEFT JOIN wealth.clients cl ON cl.id = cbw.client_id

LEFT JOIN wealth.client_administrator_wallets caw ON caw.code = sh.code
LEFT JOIN wealth.clients cl2 ON cl2.id = caw.client_id

WHERE pr.id NOT IN (15, 16, 12, 25, 2, 10, 14)
-- 	AND COALESCE(cl.name, cl2.name, sh.name) LIKE '%PLANO%'

GROUP BY cbw.id, cbw.annulled_at, sh.id, COALESCE(cl.name, cl2.name, sh.name), cspp.reference_date, funds.name, sh.allocator_id, COALESCE(cbw.id, caw.id), COALESCE(cl.attendance_id, cl2.attendance_id), sh.distributor_id, companies.name, com2.name, COALESCE(cl.user_id, cl2.user_id), COALESCE(cl.is_non_resident_investor, cl2.is_non_resident_investor), pr.id
ORDER BY SUM(cspp.gross_value) DESC)

UNION

(SELECT

	cl.name AS client_name,
	
	CASE
		WHEN companies.name = 'Xp Investimentos CCTVM' THEN SUM(cbwpq.gross_value)
		WHEN companies.name = 'NetXInvestor through Pershing LLC' THEN SUM(cbwpq.gross_value) * 6
		WHEN companies.name = 'Banco Btg Pactual S.A.' THEN SUM(cbwpq.gross_value)
	END AS valor_bruto,
	
	CASE
		WHEN companies.name = 'Xp Investimentos CCTVM' THEN 'CART. ADM. XP'
		WHEN companies.name = 'NetXInvestor through Pershing LLC' THEN 'OFFSHORE (BRL)'
		WHEN companies.name = 'Banco Btg Pactual S.A.' THEN 'CART. ADM. BTG'
	END AS produto,
 
 	CASE
 		WHEN companies.name IS NOT NULL THEN 'Real Investor - Wealth'
 	END AS layer1,
 
 	companies.name AS layer2,
 	'CARTEIRA ADM' AS estrategia,
 	cbwpq.updated_at::DATE AS reference_date
	
FROM wealth.clients cl

JOIN wealth.client_broker_wallets cbw ON cbw.client_id = cl.id
JOIN wealth.client_broker_wallet_product_quotas cbwpq ON cbwpq.client_broker_wallet_id = cbw.id
JOIN wealth.brokers ON brokers.id = cbw.broker_id
JOIN public.companies ON companies.id = brokers.company_id
JOIN wealth.products pr ON cbwpq.product_id = pr.id

WHERE cbwpq.is_current = TRUE
	AND cbwpq.gross_value > 0

GROUP BY cl.name, companies.name, cbwpq.updated_at
ORDER BY cl.name)

-- WHERE client_name LIKE '%PLANO%'
ORDER BY valor_bruto DESC