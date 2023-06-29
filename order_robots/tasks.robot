*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.

Library             RPA.HTTP
Library             RPA.Browser.Selenium    auto_close=${FALSE}
Library             RPA.Excel.Files
Library             RPA.Tables
Library             RPA.Robocorp.WorkItems
Library             RPA.PDF
Library             RPA.FileSystem
Library             RPA.Desktop
Library             RPA.Archive


*** Tasks ***
Submit robot orders from csv file
    Open the robot orders website
    Download csv orders
    Empty receipts directory
    Submit orders from csv
    Create zip archive of all orders
    [Teardown]    Close browser and clean up


*** Keywords ***
Open the robot orders website
    Open Available Browser    https://robotsparebinindustries.com/#/robot-order

Download csv orders
    Download    https://robotsparebinindustries.com/orders.csv    overwrite=True    verify=False

Empty receipts directory
    ${status}=    Does Directory Not Exist    ${OUTPUT_DIR}${/}order_receipts
    IF    ${status} == ${True}
        Create Directory    ${OUTPUT_DIR}${/}order_receipts
    ELSE
        Empty Directory    ${OUTPUT_DIR}${/}order_receipts
    END

Submit order
    [Arguments]    ${robot_order}
    # Choosing to use the class "btn btn-dark" to locate the Ok button.
    # After inspecting the page it is the only thing that uses it.
    Wait Until Page Contains Element    css:#root > div > div.modal > div > div > div > div > div > button.btn.btn-dark
    Click Button    css:#root > div > div.modal > div > div > div > div > div > button.btn.btn-dark
    Wait Until Page Contains Element    css:#head

    # Table(columns=['Order number', 'Head', 'Body', 'Legs', 'Address'], rows=20)
    Log    ${robot_order}

    Select From List By Value    css:#head    ${robot_order}[Head]
    # Found that when select radio button doesn't work just try click element.
    # DBD Thu Jun 29 08:55:13 EDT 2023
    Click Element    id:id-body-${robot_order}[Body]
    Input Text    address    ${robot_order}[Address]

    Input Text
    ...    xpath:/html/body/div/div/div[1]/div/div[1]/form/div[3]/input
    ...    ${robot_order}[Legs]
    ...

    Click Button    preview

    # Take Screenshot of the robot image
    Screenshot
    ...    css:#robot-preview-image
    ...    ${OUTPUT_DIR}${/}order_receipts${/}robot_image_${robot_order}[Order number].png

    ${keep_looping}=    Set Variable    ${True}
    ${max_tries}=    Set Variable    10

    FOR    ${i}    IN RANGE    ${max_tries}
        Wait Until Keyword Succeeds    5 times    2 seconds    Click Button    css:#order
        ${status}    ${message}=    Run Keyword and Ignore Error
        ...    Wait Until Page Contains Element
        ...    css:#order-another

        IF    '${status}' == 'PASS'
            ${keep_looping}=    Set Variable    ${False}
            Log    Found receipt. Continuing.
            BREAK
        ELSE
            Log    Didn't find receipt. Try ${i}/${max_tries}.
            Click Button    preview
        END
    END

    IF    ${keep_looping} == ${True}
        Log
        ...    Something must be seriously wrong. After 10 attempts the submit continues to error out. Unable to continue.
        Fail
    END

    Get receipt    ${robot_order}[Order number]

Submit orders from csv
    ${robot_orders}=    Read table from CSV    orders.csv    header=${True}
    Log    ${robot_orders}
    FOR    ${robot_order}    IN    @{robot_orders}
        Log    ${robot_order}
        Submit order    ${robot_order}
        Click Button    css:#order-another
        # Used for testing just the first order.
        # BREAK
    END

Get receipt
    [Arguments]    ${order_no}
    ${order_receipt_html}=    Get Element Attribute    id:receipt    outerHTML
    Html To Pdf    ${order_receipt_html}    ${OUTPUT_DIR}${/}order_receipts${/}order_${order_no}_receipt.pdf
    Open Pdf    ${OUTPUT_DIR}${/}order_receipts${/}order_${order_no}_receipt.pdf
    Add Watermark Image To Pdf
    ...    ${OUTPUT_DIR}${/}order_receipts${/}robot_image_${order_no}.png
    ...    ${OUTPUT_DIR}${/}order_receipts${/}order_${order_no}_receipt.pdf
    Close Pdf    ${OUTPUT_DIR}${/}order_receipts${/}order_${order_no}_receipt.pdf

Create zip archive of all orders
    Archive Folder With Zip
    ...    folder=${OUTPUT_DIR}${/}order_receipts
    ...    archive_name=${OUTPUT_DIR}${/}order_receipts_archive.zip

Close browser and clean up
    Close Browser
