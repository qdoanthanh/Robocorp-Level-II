# +
*** Settings ***
Documentation     Orders robots from RobotSpareBin Industries Inc.
...               Saves the order HTML receipt as a PDF file.
...               Saves the screenshot of the ordered robot.
...               Embeds the screenshot of the robot to the PDF receipt.
...               Creates ZIP archive of the receipts and the images.

Library     RPA.Browser
Library     RPA.HTTP
Library     RPA.Tables
Library     RPA.PDF
Library     RPA.Archive
Library     RPA.Dialogs
Library     RPA.Robocorp.Vault
# -

*** Variables ***
${GLOBAL_RETRY_AMOUNT}=    5x
${GLOBAL_RETRY_INTERVAL}=    0.5s

*** Keywords ***
Input form dialog
    Add heading    Input Order data download URL
    Add text input      url     label=Order data URL
    ${result}=      Run dialog     title=Input form
    [Return]        ${result.url}

*** Keywords ***
Open the robot order website
    ${Order_website}=       Get Secret    Order_website
    Open Available Browser      ${Order_website}[INTRANET_URL]
    Wait Until Element Is Visible    css:LI.nav-item:nth-child(2)
    Click Element    css:LI.nav-item:nth-child(2)

*** Keywords ***
Get orders
    [Arguments]     ${URL}
    Download    ${URL}    overwrite=True
    ${orders}=  Read table from CSV    orders.csv
    [Return]    ${orders}

*** Keywords ***
Close the annoying modal    
    Click Element When Visible    css:BUTTON.btn.btn-warning

*** Keywords ***
Fill the form
    [Arguments]     ${row}
    Select From List By Index    id:head    ${row}[Head]
    #${target_as_string}=     Convert To String    ${row}[Body]
    #${body_index}=   Catenate  id-body-${target_as_string}
    Click Button    id:id-body-${row}[Body]
    Input Text    css:input[placeholder="Enter the part number for the legs"]    ${row}[Legs]
    Input Text    id:address    ${row}[Address]

*** Keywords ***
Preview the robot
    Click Button    id:preview
    Wait Until Page Contains Element    id:robot-preview-image

*** Keywords ***
Submit the order
    Click Button    id:order
    Wait Until Element Is Visible    id:receipt

*** Keywords ***
Store the receipt as a PDF file
    [Arguments]        ${order_number}
    ${sales_results_html}=    Get Element Attribute    id:receipt    outerHTML
    ${pdf}=   Catenate  ${CURDIR}${/}output${/}receipts${/}${order_number}.pdf
    Html To Pdf    ${sales_results_html}    ${pdf}
    [Return]    ${pdf}

*** Keywords ***
Take a screenshot of the robot
    [Arguments]        ${order_number}
    ${screenshot}=      Catenate    ${CURDIR}${/}output${/}screenshots${/}${order_number}.png
    Screenshot      id:robot-preview-image    ${screenshot}
    [Return]        ${screenshot}

*** Keywords ***
Embed the robot screenshot to the receipt PDF file
    [Arguments]        ${pdf}
    ...                ${screenshot}
    #Open Pdf    ${pdf}
    ${files}=    Create List
    ...    ${screenshot}
    Add Files To PDF    ${files}    ${pdf}
    #[Teardown]      Close All Pdfs

*** Keywords ***
Go to order another robot
    Click Button    id:order-another
    Wait Until Element Is Visible    css:BUTTON.btn.btn-warning

*** Keywords ***
Create a ZIP file of the receipts
    Archive Folder With Zip     ${CURDIR}${/}output${/}receipts     ${CURDIR}${/}output${/}receipts.zip    recursive=True

*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    ${URL}=     Input form dialog
    Open the robot order website
    ${orders}=    Get orders    ${URL}
    FOR    ${row}    IN    @{orders}
        Close the annoying modal
        Fill the form    ${row}
        Preview the robot        
        Wait Until Keyword Succeeds  
        ...     ${GLOBAL_RETRY_AMOUNT}
        ...     ${GLOBAL_RETRY_INTERVAL}
        ...     Submit the order
        ${pdf}=    Store the receipt as a PDF file    ${row}[Order number]
        ${screenshot}=    Take a screenshot of the robot    ${row}[Order number]
        Embed the robot screenshot to the receipt PDF file    ${screenshot}    ${pdf}
        Go to order another robot
        #Exit For Loop
    END
    Create a ZIP file of the receipts
    [Teardown]  Close All Browsers
