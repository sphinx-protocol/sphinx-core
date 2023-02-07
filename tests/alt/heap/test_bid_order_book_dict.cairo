%lang starknet

from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.dict import dict_read

from src.heap.bid_order_book import (
    bob_create, bob_insert, bob_extract, bob_write_to_storage, bob_read_one_from_storage
)

@external
func test_bid_order_book_dict{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
} () {
    alloc_locals;
    // Create heap
    let (bob_prices, bob_datetimes, bob_ids, bob_len) = bob_create();

    // Insert values to heap
    bob_insert{bob_prices=bob_prices, bob_datetimes=bob_datetimes, bob_ids=bob_ids, bob_len=bob_len}(
        order_price=78, order_datetime=9952, order_id=3693265
    ); 
    bob_insert{bob_prices=bob_prices, bob_datetimes=bob_datetimes, bob_ids=bob_ids, bob_len=bob_len}(
        order_price=95, order_datetime=9956, order_id=19075640
    );
    bob_insert{bob_prices=bob_prices, bob_datetimes=bob_datetimes, bob_ids=bob_ids, bob_len=bob_len}(
        order_price=95, order_datetime=8000, order_id=466
    );    
    bob_insert{bob_prices=bob_prices, bob_datetimes=bob_datetimes, bob_ids=bob_ids, bob_len=bob_len}(
        order_price=48, order_datetime=8870, order_id=9544525
    );
    bob_insert{bob_prices=bob_prices, bob_datetimes=bob_datetimes, bob_ids=bob_ids, bob_len=bob_len}(
        order_price=96, order_datetime=9955, order_id=3693265
    );
    bob_insert{bob_prices=bob_prices, bob_datetimes=bob_datetimes, bob_ids=bob_ids, bob_len=bob_len}(
        order_price=96, order_datetime=9952, order_id=7547619
    );
    bob_insert{bob_prices=bob_prices, bob_datetimes=bob_datetimes, bob_ids=bob_ids, bob_len=bob_len}(
        order_price=48, order_datetime=8278, order_id=35533
    );
    bob_insert{bob_prices=bob_prices, bob_datetimes=bob_datetimes, bob_ids=bob_ids, bob_len=bob_len}(
        order_price=48, order_datetime=8870, order_id=25011021
    );

    // Test insertion has been done correctly
    let (elem1_price) = dict_read{dict_ptr=bob_prices}(key=0);
    assert elem1_price = 96;
    let (elem2_price) = dict_read{dict_ptr=bob_prices}(key=1);
    assert elem2_price = 95;
    let (elem3_price) = dict_read{dict_ptr=bob_prices}(key=2);
    assert elem3_price = 96;
    let (elem4_price) = dict_read{dict_ptr=bob_prices}(key=3);
    assert elem4_price = 48;
    let (elem5_price) = dict_read{dict_ptr=bob_prices}(key=4);
    assert elem5_price = 78;
    let (elem6_price) = dict_read{dict_ptr=bob_prices}(key=5);
    assert elem6_price = 95;
    let (elem7_price) = dict_read{dict_ptr=bob_prices}(key=6);
    assert elem7_price = 48;
    let (elem8_price) = dict_read{dict_ptr=bob_prices}(key=7);
    assert elem8_price = 48;
    
    let (elem1_datetime) = dict_read{dict_ptr=bob_datetimes}(key=0);
    assert elem1_datetime = 9952;
    let (elem2_datetime) = dict_read{dict_ptr=bob_datetimes}(key=1);
    assert elem2_datetime = 8000;
    let (elem3_datetime) = dict_read{dict_ptr=bob_datetimes}(key=2);
    assert elem3_datetime = 9955;

    // Delete root value
    let (root_price, root_datetime, root_id) = bob_extract{bob_prices=bob_prices, bob_datetimes=bob_datetimes, bob_ids=bob_ids, bob_len=bob_len}();

    // Check sink down executed correctly
    assert root_price = 96;
    assert root_datetime = 9952;
    assert root_id = 7547619;

    let (updated_elem1_price) = dict_read{dict_ptr=bob_prices}(key=0);
    assert updated_elem1_price = 96;
    let (updated_elem3_price) = dict_read{dict_ptr=bob_prices}(key=2);
    assert updated_elem3_price = 95;
    let (updated_elem6_price) = dict_read{dict_ptr=bob_prices}(key=5);
    assert updated_elem6_price = 48;

    let (updated_elem1_datetime) = dict_read{dict_ptr=bob_datetimes}(key=0);
    assert updated_elem1_datetime = 9955;
    let (updated_elem3_datetime) = dict_read{dict_ptr=bob_datetimes}(key=2);
    assert updated_elem3_datetime = 9956;
    let (updated_elem6_datetime) = dict_read{dict_ptr=bob_datetimes}(key=5);
    assert updated_elem6_datetime = 8870;

    // Write values to storage var
    let (final_len) = dict_read{dict_ptr=bob_len}(key=0);
    bob_write_to_storage(bob_prices, bob_datetimes, bob_ids, final_len - 1);

    // Retrieve values from storage var
    let (str_price_1, str_datetime_1, str_id_1) = bob_read_one_from_storage(0);
    assert str_price_1 = 96;
    assert str_datetime_1 = 9955;

    return ();
}